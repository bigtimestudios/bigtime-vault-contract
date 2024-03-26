// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/VaultERC20.sol";
import "src/commons/token/MintableToken.sol";

import "test/forge/AdvTest.sol";


contract VaultERC20Imp is VaultERC20 {
  constructor (
    uint8 _sweepErc20Permission,
    uint8 _sendErc20Permission,
    uint8 _sendErc20LimitPermission,
    uint8 _pausePermission
  ) VaultERC20(_sweepErc20Permission, _sendErc20Permission, _sendErc20LimitPermission) Pausable(_pausePermission) {}
}

contract TokenReturnsNothingMock {
  mapping(address => uint256) public balanceOf;

  function transfer(address _to, uint256 _amount) external {
    balanceOf[msg.sender] -= _amount;
    balanceOf[_to] += _amount;
  }

  function mint(address _to, uint256 _amount) external {
    balanceOf[_to] += _amount;
  }
}

contract TokenReturnsFalseMock {
  mapping(address => uint256) public balanceOf;

  function transfer(address _to, uint256 _amount) external returns (bool) {
    balanceOf[msg.sender] -= _amount;
    balanceOf[_to] += _amount;
    return false;
  }

  function mint(address _to, uint256 _amount) external returns (bool) {
    balanceOf[_to] += _amount;
    return true;
  }
}

contract VaultERC20Test is AdvTest {
  uint8 pausePerm = 0;
  uint8 sweepPerm = 1;
  uint8 sendPerm = 2;
  uint8 sendLimitPerm = 11;

  VaultERC20Imp vault;
  MintableToken token;
  address worker;

  function setUp() external {
    vault = new VaultERC20Imp(sweepPerm, sendPerm, sendLimitPerm, pausePerm);
    token = new MintableToken("", "", 0);

    worker = vm.addr(1);

    uint8[] memory permissions = new uint8[](2);
    permissions[0] = sweepPerm;
    permissions[1] = sendPerm;
    permissions[2] = sendLimitPerm;
    vault.addPermissions(worker, permissions);
  }

  //
  // Sweep tokens tests
  //

  function test_sweepERC20(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));
    token.mint(receiver, _balance);

    vm.prank(worker);
    vault.sweepERC20(token, _id);

    assertEq(token.balanceOf(receiver), 0);
    assertEq(token.balanceOf(address(vault)), _balance);
    assertEq(receiver.code.length != 0, _balance != 0);
  }

  function test_sweepERC20_NonExistingToken(uint256 _id) external {
    address emptyToken = vm.addr(2);

    vm.expectRevert();
    vm.prank(worker);
    vault.sweepERC20(IERC20(emptyToken), _id);
  }

  function test_sweepERC20_WithoutReturnOnTransfer(uint256 _id, uint256 _balance) external {
    TokenReturnsNothingMock token2 = new TokenReturnsNothingMock();

    address receiver = address(vault.receiverFor(_id));
    token2.mint(receiver, _balance);

    vm.prank(worker);
    vault.sweepERC20(IERC20(address(token2)), _id);

    assertEq(token2.balanceOf(receiver), 0);
    assertEq(token2.balanceOf(address(vault)), _balance);
  }

  function test_sweepERC20_SendNotPermitted(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));
    token.mint(receiver, _balance);

    vault.delPermission(worker, sendPerm);

    vm.prank(worker);
    vault.sweepERC20(token, _id);
  }

  function test_fail_sweepERC20_TokenReturnsFalse(uint256 _id, uint256 _balance) external {
    _balance = bound(_balance, 1, type(uint256).max);
    TokenReturnsFalseMock token2 = new TokenReturnsFalseMock();

    address receiver = address(vault.receiverFor(_id));
    token2.mint(receiver, _balance);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ErrorSweepingERC20(address,address,uint256,bytes)", token2, receiver, _balance, abi.encode(false)));
    vault.sweepERC20(IERC20(address(token2)), _id);
  }

  function test_fail_sweepERC20_NotPermitted(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));
    token.mint(receiver, _balance);

    vault.delPermission(worker, sweepPerm);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sweepPerm));
    vault.sweepERC20(token, _id);
  }

  function test_fail_sweepERC20_Paused(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));
    token.mint(receiver, _balance);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.sweepERC20(token, _id);
  }

  //
  // Sweep all tokens tests
  //

  function test_sweepBatchERC20_WithOneReceiver(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));
    token.mint(receiver, _balance);

    uint256[] memory ids = new uint256[](1);
    ids[0] = _id;

    vm.prank(worker);
    vault.sweepBatchERC20(token, ids);

    assertEq(token.balanceOf(receiver), 0);
    assertEq(token.balanceOf(address(vault)), _balance);
    assertEq(receiver.code.length == 0, _balance == 0);
  }

  function test_sweepBatchERC20_WithTwoDiffReceivers(uint256 _id1, uint256 _id2, uint256 _balance1, uint256 _balance2) external {
    _id2 = boundDiff(_id2, _id1);
    _balance2 = bound(_balance2, 0, type(uint256).max - _balance1);

    address receiver1 = address(vault.receiverFor(_id1));
    address receiver2 = address(vault.receiverFor(_id2));

    token.mint(receiver1, _balance1);
    token.mint(receiver2, _balance2);

    uint256[] memory ids = new uint256[](2);
    ids[0] = _id1;
    ids[1] = _id2;

    vm.prank(worker);
    vault.sweepBatchERC20(token, ids);

    assertEq(token.balanceOf(receiver1), 0);
    assertEq(token.balanceOf(receiver2), 0);
    assertEq(token.balanceOf(address(vault)), _balance1 + _balance2);
    assertEq(receiver1.code.length == 0, _balance1 == 0);
    assertEq(receiver2.code.length == 0, _balance2 == 0);
  }

  function test_sweepBatchERC20_WithSameReceiverTwice(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));
    token.mint(receiver, _balance);

    uint256[] memory ids = new uint256[](2);
    ids[0] = _id;
    ids[1] = _id;

    vm.prank(worker);
    vault.sweepBatchERC20(token, ids);

    assertEq(token.balanceOf(receiver), 0);
    assertEq(token.balanceOf(address(vault)), _balance);
    assertEq(receiver.code.length == 0, _balance == 0);
  }

  struct IdAndBalance {
    uint256 id;
    uint256 balance;
  }

  function _splitAndMint(
    IdAndBalance[10] memory _idsAndBalances,
    bool _doMint,
    uint256 _size
  ) internal returns (
    Receiver[] memory receivers,
    uint256[] memory ids,
    uint256[] memory balances,
    uint256 total
  ) {
    _size = bound(_size, 0, 10);

    receivers = new Receiver[](_size);
    ids = new uint256[](_size);
    balances = new uint256[](_size);

    for (uint256 i = 0; i < _size; i++) {
      IdAndBalance memory v = _idsAndBalances[i];

      receivers[i] = vault.receiverFor(v.id);

      ids[i] = v.id;
      uint256 balance = bound(v.balance, 0, type(uint256).max - total);
      balances[i] = balance;
      total += balance;
      if (_doMint) {
        (bool success,) = address(token).call(abi.encodeWithSelector(token.mint.selector, address(receivers[i]), balance));
        require(success);
      }
    }
  }

  function test_sweepBatchERC20_WithManyReceivers(IdAndBalance[10] calldata _idsAndBalances, uint256 _size) external {
    (
      Receiver[] memory receivers,
      uint256[] memory ids,,
      uint256 total
    ) = _splitAndMint(_idsAndBalances, true, _size);

    vm.prank(worker);
    vault.sweepBatchERC20(token, ids);

    assertEq(token.balanceOf(address(vault)), total);
    for (uint256 i = 0; i < receivers.length; i++) {
      assertEq(token.balanceOf(address(receivers[i])), 0);
    }
  }

  function test_fail_sweepBatchERC20_NotPermitted(IdAndBalance[10] calldata _idsAndBalances, uint256 _size) external {
    (,uint256[] memory ids,,) = _splitAndMint(_idsAndBalances, true, _size);

    vault.delPermission(worker, sweepPerm);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sweepPerm));
    vault.sweepBatchERC20(token, ids);
  }

  function test_fail_sweepBatchERC20_NonExistentToken(IdAndBalance[10] calldata _idsAndBalances, uint256 _size) external {
    (,uint256[] memory ids,,) = _splitAndMint(_idsAndBalances, false, _size);
    address emptyToken = vm.addr(2);

    vm.prank(worker);

    if (ids.length > 0) vm.expectRevert();
    vault.sweepBatchERC20(IERC20(emptyToken), ids);
  }

  function test_fail_sweepBatchERC20_TokenReturnsFalse(uint256 _from1, uint256 _balance1, uint256 _from2, uint256 _balance2) external {
    _balance2 = bound(_balance2, 0, type(uint256).max - _balance1);
    if (_balance1 == 0 && _balance2 == 0) _balance1 = 1;

    TokenReturnsFalseMock token2 = new TokenReturnsFalseMock();

    address receiver1 = address(vault.receiverFor(_from1));
    address receiver2 = address(vault.receiverFor(_from2));

    token2.mint(receiver1, _balance1);
    token2.mint(receiver2, _balance2);

    uint256[] memory ids = new uint256[](2);
    ids[0] = _from1;
    ids[1] = _from2;

    bool failsFirst = _balance1 != 0;
    address freceiver = failsFirst ? receiver1 : receiver2;
    uint256 fbalance = token2.balanceOf(freceiver);

    vm.expectRevert(abi.encodeWithSignature("ErrorSweepingERC20(address,address,uint256,bytes)", token2, freceiver, fbalance, abi.encode(false)));
    vm.prank(worker);
    vault.sweepBatchERC20(IERC20(address(token2)), ids);
  }

  function test_sweepBatchERC20_TokenReturnsNothing(IdAndBalance[10] memory _idsAndBalances, uint256 _size) external {
    token = MintableToken(address(new TokenReturnsNothingMock()));

    (
      Receiver[] memory receivers,
      uint256[] memory ids,,
      uint256 total
    ) = _splitAndMint(_idsAndBalances, true, _size);

    vm.prank(worker);
    vault.sweepBatchERC20(token, ids);

    assertEq(token.balanceOf(address(vault)), total);
    for (uint256 i = 0; i < receivers.length; i++) {
      assertEq(token.balanceOf(address(receivers[i])), 0);
    }
  }

  function test_sweepBatchERC20_empty() external {
    // This is a no-op
    vm.prank(worker);
    uint256[] memory ids = new uint256[](0);
    vm.record();
    vault.sweepBatchERC20(token, ids);
    (,bytes32[] memory vaultWrites) = vm.accesses(address(vault));
    assertEq(vaultWrites.length, 0);
  }

  function test_fail_sweepBatchERC20_Paused(IdAndBalance[10] memory _idsAndBalances, uint256 _size) external {
    (,uint256[] memory ids,,) = _splitAndMint(_idsAndBalances, true, _size);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.sweepBatchERC20(token, ids);
  }

  //
  // Send tokens
  //

  function test_sendERC20(address _to, uint256 _balance, uint256 _amount) external {
    _amount = bound(_amount, 0, _balance);

    token.mint(address(vault), _balance);

    vm.prank(worker);
    vault.sendERC20(token, _to, _amount);

    if (address(vault) != _to) {
      assertEq(token.balanceOf(address(vault)), _balance - _amount);
      assertEq(token.balanceOf(_to), _amount);
    } else {
      assertEq(token.balanceOf(address(vault)), _balance);
    }
  }

  function test_fail_sendERC20_AboveBalance(address _to, uint256 _balance, uint256 _amount) external {
    _balance = bound(_balance, 0, type(uint256).max - 1);
    _amount = bound(_amount, _balance + 1, type(uint256).max);

    token.mint(address(vault), _balance);

    vm.prank(worker);

    bytes memory nestedErr = abi.encodeWithSignature("NotEnoughBalance(address,uint256,uint256)", address(vault), _balance, _amount);
    bytes memory err = abi.encodeWithSignature("ErrorSendingERC20(address,address,uint256,bytes)", address(token), _to, _amount, nestedErr);

    vm.expectRevert(err);
    vault.sendERC20(token, _to, _amount);
  }

  function test_fail_sendERC20_NotPermitted(address _to, uint256 _balance, uint256 _amount) external {
    token.mint(address(vault), _balance);

    vault.delPermission(worker, sendPerm);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sendPerm));
    vault.sendERC20(token, _to, _amount);
  }

  function test_fail_sendERC20_NotWorker(address _notworker, address _to, uint256 _balance, uint256 _amount) external {
    _notworker = boundDiff(_notworker, address(worker), address(this));

    token.mint(address(vault), _balance);

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, sendPerm));
    vault.sendERC20(token, _to, _amount);
  }

  function test_sendERC20_ReturnsNothing(address _to, uint256 _balance, uint256 _amount) external {
    _amount = bound(_amount, 0, _balance);

    TokenReturnsNothingMock altToken = new TokenReturnsNothingMock();
    altToken.mint(address(vault), _balance);

    vm.prank(worker);
    vault.sendERC20(IERC20(address(altToken)), _to, _amount);

    if (address(vault) != _to) {
      assertEq(altToken.balanceOf(address(vault)), _balance - _amount);
      assertEq(altToken.balanceOf(_to), _amount);
    } else {
      assertEq(altToken.balanceOf(address(vault)), _balance);
    }
  }

  function test_fail_sendERC20_ReturnsFalse(address _to, uint256 _balance, uint256 _amount) external {
    _amount = bound(_amount, 0, _balance);

    TokenReturnsFalseMock altToken = new TokenReturnsFalseMock();
    altToken.mint(address(vault), _balance);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ErrorSendingERC20(address,address,uint256,bytes)", address(altToken), _to, _amount, abi.encode(false)));
    vault.sendERC20(IERC20(address(altToken)), _to, _amount);
  }

  function test_fail_sendERC20_Paused(address _to, uint256 _balance, uint256 _amount) external {
    token.mint(address(vault), _balance);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.sendERC20(IERC20(address(token)), _to, _amount);
  }

  //
  // Send many tokens
  //

  struct Send {
    address to;
    uint256 amount;
  }

  function _splitSendArray(
    Send[] memory _sends
  ) internal returns (
    address[] memory _tos,
    uint256[] memory _amounts,
    uint256 _total
  ) {
    uint256 size = mayBoundArr(_sends.length);

    _tos = new address[](size);
    _amounts = new uint256[](size);
    _total = 0;

    for (uint256 i = 0; i < size; i++) {
      _amounts[i] = bound(_sends[i].amount, 0, type(uint256).max - _total);
      _total += _amounts[i];
    }
  }

  function test_sendBatchERC20(Send[] memory _sends, uint256 _leftover) public {
    (
      address[] memory _tos,
      uint256[] memory _amounts,
      uint256 _total
    ) = _splitSendArray(_sends);

    _leftover = bound(_leftover, 0, type(uint256).max - _total);
    token.mint(address(vault), _total + _leftover);

    vm.prank(worker);
    vault.sendBatchERC20(token, _tos, _amounts);

    uint256 totalToVault;
    for (uint256 i = 0; i < _tos.length; i++) {
      if (_tos[i] == address(vault)) {
        totalToVault += _amounts[i];
      } else {
        uint256 totalToThis;

        for (uint256 j = 0; j < _tos.length; j++) {
          if (_tos[j] == _tos[i]) {
            totalToThis += _amounts[j];
          }
        }

        assertEq(token.balanceOf(_tos[i]), totalToThis);
      }
    }

    assertEq(token.balanceOf(address(vault)), _leftover + totalToVault);
  }

  function test_fail_sendBatchERC20_NotPermitted(Send[] memory _sends, uint256 _leftover) external {
    (
      address[] memory _tos,
      uint256[] memory _amounts,
      uint256 _total
    ) = _splitSendArray(_sends);

    _leftover = bound(_leftover, 0, type(uint256).max - _total);

    token.mint(address(vault), _total + _leftover);

    vault.delPermission(worker, sendPerm);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sendPerm));
    vault.sendBatchERC20(token, _tos, _amounts);
  }

  function test_fail_sendBatchERC20_NotWorker(address _notworker, Send[] memory _sends, uint256 _leftover) external {
    _notworker = boundDiff(_notworker, address(worker), address(this));

    (
      address[] memory _tos,
      uint256[] memory _amounts,
      uint256 _total
    ) = _splitSendArray(_sends);

    _leftover = bound(_leftover, 0, type(uint256).max - _total);

    token.mint(address(vault), _total + _leftover);

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, sendPerm));
    vault.sendBatchERC20(token, _tos, _amounts);
  }

  function test_sendBatchERC20_ReturnsEmptyToken(Send[] memory _sends, uint256 _leftover) external {
    (
      address[] memory _tos,
      uint256[] memory _amounts,
      uint256 _total
    ) = _splitSendArray(_sends);

    _leftover = bound(_leftover, 0, type(uint256).max - _total);

    TokenReturnsNothingMock altToken = new TokenReturnsNothingMock();
    altToken.mint(address(vault), _total + _leftover);

    vm.prank(worker);
    vault.sendBatchERC20(IERC20(address(altToken)), _tos, _amounts);

    uint256 totalToVault;
    for (uint256 i = 0; i < _tos.length; i++) {
      if (_tos[i] == address(vault)) {
        totalToVault += _amounts[i];
      } else {
        uint256 totalToThis;

        for (uint256 j = 0; j < _tos.length; j++) {
          if (_tos[j] == _tos[i]) {
            totalToThis += _amounts[j];
          }
        }

        assertEq(altToken.balanceOf(_tos[i]), totalToThis);
      }
    }

    assertEq(altToken.balanceOf(address(vault)), _leftover + totalToVault);
  }

  function test_fail_sendBatchERC20_ReturnsFalseToken(Send[] memory _sends, uint256 _leftover) external {
    (
      address[] memory _tos,
      uint256[] memory _amounts,
      uint256 _total
    ) = _splitSendArray(_sends);

    vm.assume(_amounts.length > 0);

    if (_amounts[0] == 0) {
      vm.assume(_total != type(uint256).max);

      _amounts[0] = 1;
      _total += 1;
    }

    _leftover = bound(_leftover, 0, type(uint256).max - _total);

    TokenReturnsFalseMock altToken = new TokenReturnsFalseMock();
    altToken.mint(address(vault), _total + _leftover);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ErrorSendingERC20(address,address,uint256,bytes)", address(altToken), _tos[0], _amounts[0], abi.encode(false)));
    vault.sendBatchERC20(IERC20(address(altToken)), _tos, _amounts);
  }

  function test_fail_sendBatchERC20_DiffLengths(uint8 _tosLength, uint8 _amountLenghth) external {
    _tosLength = uint8(boundDiff(_tosLength, _amountLenghth));

    address[] memory _tos = new address[](_tosLength);
    uint256[] memory _amounts = new uint256[](_amountLenghth);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ArrayLengthMismatchERC20(uint256,uint256)", _tosLength, _amountLenghth));
    vault.sendBatchERC20(token, _tos, _amounts);
  }

  function test_fail_sendBatchERC20_Paused(Send[] memory _sends) external {
    (
      address[] memory _tos,
      uint256[] memory _amounts,
      uint256 _total
    ) = _splitSendArray(_sends);

    token.mint(address(vault), _total);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.sendBatchERC20(IERC20(address(token)), _tos, _amounts);
  }
}
