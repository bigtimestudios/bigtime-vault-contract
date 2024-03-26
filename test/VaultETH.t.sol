// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/VaultETH.sol";
import "src/commons/token/MintableToken.sol";

import "test/forge/AdvTest.sol";


contract VaultETHImp is VaultETH {
  constructor (
    uint8 _sweepETHPermission,
    uint8 _sendETHPermission,
    uint8 _pausePermission
  ) VaultETH(_sweepETHPermission, _sendETHPermission) Pausable(_pausePermission) {}
}

contract RejectsTransfer {
  bytes reason;

  error Reverted(bytes reason);

  constructor(bytes memory _reason) {
    reason = _reason;
  }

  receive() external payable {
    revert Reverted(reason);
  }
}

contract VaultETHTest is AdvTest {
  uint8 pausePerm = 0;
  uint8 sweepPerm = 1;
  uint8 sendPerm = 2;

  VaultETHImp vault;
  address worker;

  function setUp() external {
    vault = new VaultETHImp(sweepPerm, sendPerm, pausePerm);

    worker = vm.addr(1);

    vault.addPermission(worker, sweepPerm);
    vault.addPermission(worker, sendPerm);
  }

  //
  // Sweep eth tests
  //
  function test_sweepETH(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));

    vm.deal(receiver, _balance);
    vm.prank(worker);
    vault.sweepETH(_id);

    assertEq(receiver.balance, 0);
    assertEq(address(vault).balance, _balance);
    assertEq(receiver.code.length == 0, _balance == 0);
  }

  struct IdAndBalance {
    uint256 id;
    uint256 balance;
  }

  function _splitAndMint(
    IdAndBalance[] memory _idsAndBalances
  ) internal returns (
    Receiver[] memory receivers,
    uint256[] memory ids,
    uint256 total
  ) {
    uint256 size = mayBoundArr(_idsAndBalances.length);

    receivers = new Receiver[](size);
    ids = new uint256[](size);

    for (uint256 i = 0; i < size; i++) {
      IdAndBalance memory v = _idsAndBalances[i];

      receivers[i] = vault.receiverFor(v.id);
      ids[i] = v.id;

      uint256 balance = bound(v.balance, 0, type(uint256).max - total);

      total += balance;
      vm.deal(address(receivers[i]), address(receivers[i]).balance + balance);
    }
  }

  function test_sweepBatchETH(IdAndBalance[] calldata _idsAndBalances) external {
    (
      Receiver[] memory receivers,
      uint256[] memory ids,
      uint256 total
    ) = _splitAndMint(_idsAndBalances);

    bool[] memory hadBalance = new bool[](ids.length);

    for (uint256 i = 0; i < receivers.length; ++i) {
      if (address(receivers[i]).balance != 0) {
        hadBalance[i] = true;
      }
    }

    vm.prank(worker);
    vault.sweepBatchETH(ids);

    for (uint256 i = 0; i < ids.length; ++i) {
      assertEq(address(receivers[i]).balance, 0);
      assertEq(address(receivers[i]).code.length == 0, !hadBalance[i]);
    }

    assertEq(address(vault).balance, total);
  }

  function test_fail_sweepETH_PermissionRemoved(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));

    vm.deal(receiver, _balance);
    vault.delPermission(worker, sweepPerm);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sweepPerm));
    vault.sweepETH(_id);
  }

  function test_fail_sweepETH_NotWorker(address _notworker, uint256 _id, uint256 _balance) external {
    _notworker = boundDiff(_notworker, worker, address(this));
    address receiver = address(vault.receiverFor(_id));
    vm.deal(receiver, _balance);

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, sweepPerm));
    vault.sweepETH(_id);
  }

  function test_fail_sweepBatchETH_PermissionsRemoved(IdAndBalance[] calldata _idsAndBalances) external {
    (,uint256[] memory ids,) = _splitAndMint(_idsAndBalances);

    vault.delPermission(worker, sweepPerm);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sweepPerm));
    vault.sweepBatchETH(ids);
  }

  function test_fail_sweepBatchETH_NotWorker(address _notworker, IdAndBalance[] calldata _idsAndBalances) external {
    _notworker = boundDiff(_notworker, worker, address(this));

    (,uint256[] memory ids,) = _splitAndMint(_idsAndBalances);

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, sweepPerm));
    vault.sweepBatchETH(ids);
  }

  function test_fail_sweepETH_Paused(uint256 _id, uint256 _balance) external {
    address receiver = address(vault.receiverFor(_id));
    vm.deal(receiver, _balance);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.sweepETH(_id);
  }

  function test_fail_sweepBatchETH_Paused(IdAndBalance[] calldata _idsAndBalances) external {
    (,uint256[] memory ids,) = _splitAndMint(_idsAndBalances);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.sweepBatchETH(ids);
  }

  //
  // Send ETH tests
  //

  function test_sendETH(address payable _to, uint256 _balance, uint256 _amount) public {
    _to = payable(boundNoSys(_to));
    _amount = bound(_amount, 0, _balance);
    vm.deal(_to, 0);

    vm.deal(address(vault), _balance);

    vm.prank(worker);
    vault.sendETH(_to, _amount);

    if (_to == address(vault)) {
      assertEq(address(vault).balance, _balance);
    } else {
      assertEq(address(vault).balance, _balance - _amount);
      assertEq(_to.balance, _amount);
    }
  }

  function test_sendETH_replicate1() external {
    address to = address(0x001804c8ab1f12e6bbf3894d4083f33e07309d1f38);
    uint256 balance = 0;
    uint256 amount = 0;
    test_sendETH(payable(to), balance, amount);
  }

  function test_sendETH_replicate2() external {
    address to = address(0x00000000000000000000636f6e736f6c652e6c6f67);
    uint256 balance = 1356938545749799165119972480570561420155507632800475359837393562592731987968;
    uint256 amount = 24511836422326971499928815417808519888082284119755867791443345950799916709945;
    test_sendETH(payable(to), balance, amount);
  }

  function test_fail_sendETH_NotEnoughBalance(address payable _to, uint256 _balance, uint256 _amount) public {
    _to = payable(boundNoSys(_to));
    _balance = bound(_balance, 0, type(uint256).max - 1);
    _amount = bound(_amount, _balance + 1, type(uint256).max);

    vm.deal(address(vault), _balance);
    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ErrorSendingETH(address,uint256,bytes)", _to, _amount, bytes("")));
    vault.sendETH(_to, _amount);
  }

  function test_fail_sendETH_NotEnoughBalance_replicate1() external {
    test_fail_sendETH_NotEnoughBalance(
      payable(address(0x007109709ecfa91a80626ff3989d68f67f5b1dd12d)),
      363481960551815251945962924583801202217685635938,
      1032069922050249630382865877677304880282300743300
    );
  }

  function test_fail_sendETH_Rejected(uint256 _balance, uint256 _amount, bytes calldata _reason) external {
    _amount = bound(_amount, 0, _balance);

    RejectsTransfer rt = new RejectsTransfer(_reason);

    vm.deal(address(vault), _balance);
    vm.prank(worker);

    bytes memory nestedErr = abi.encodeWithSignature("Reverted(bytes)", _reason);
    vm.expectRevert(abi.encodeWithSignature("ErrorSendingETH(address,uint256,bytes)", address(rt), _amount, nestedErr));
    vault.sendETH(payable(address(rt)), _amount);
  }

  function test_fail_sendETH_Paused(address payable _to, address _worker, uint256 _balance, uint256 _amount) external {
    _to = payable(boundNoSys(_to));

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.deal(address(vault), _balance);
    vm.prank(_worker);

    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.sendETH(_to, _amount);
  }

  function test_fail_sendETH_PermissionRemoved(address payable _to, uint256 _balance, uint256 _amount) external {
    _to = payable(boundNoSys(_to));

    vault.delPermission(worker, sendPerm);

    vm.deal(address(vault), _balance);
    vm.prank(worker);

    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sendPerm));
    vault.sendETH(_to, _amount);
  }

  function test_fail_sendETH_NotWorker(address payable _to, address _notworker, uint256 _balance, uint256 _amount) external {
    _to = payable(boundNoSys(_to));

    _notworker = boundDiff(_notworker, worker, address(this));

    vm.deal(address(vault), _balance);
    vm.prank(_notworker);

    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, sendPerm));
    vault.sendETH(_to, _amount);
  }

  //
  // Send ETH batch tests
  //

  struct IdAndAmount {
    address payable to;
    uint256 balance;
  }

  function _splitIdAndAmounts(
    IdAndAmount[] memory _idsAmounts
  ) internal returns (
    address payable[] memory tos,
    uint256[] memory amounts,
    uint256 total
  ) {
    uint256 size = mayBoundArr(_idsAmounts.length);

    tos = new address payable[](size);
    amounts = new uint256[](size);

    for (uint256 i = 0; i < size; i++) {
      IdAndAmount memory v = _idsAmounts[i];

      tos[i] = payable(boundNoSys(v.to));
      amounts[i] = bound(v.balance, 0, type(uint256).max - total);
      total += amounts[i];

      vm.deal(tos[i], 0);
    }
  }

  function test_sendBatchETH(IdAndAmount[] calldata _idsAmounts, uint256 _extraBalance) external {
    (
      address payable[] memory tos,
      uint256[] memory amounts,
      uint256 total
    ) = _splitIdAndAmounts(_idsAmounts);

    _extraBalance = bound(_extraBalance, 0, type(uint256).max - total);

    vm.deal(address(vault), total + _extraBalance);

    vm.prank(worker);
    vault.sendBatchETH(tos, amounts);

    for (uint256 i = 0; i < tos.length; i++) {
      uint256 totalSent;

      for (uint256 j = 0; j < tos.length; j++) {
        if (tos[i] == tos[j]) {
          totalSent += amounts[j];
        }
      }

      if (tos[i] != address(vault)) {
        assertEq(tos[i].balance, totalSent);
      } else {
        assertEq(address(vault).balance, _extraBalance + totalSent);
      }
    }
  }

  function test_fail_sendBatchETH_Paused(IdAndAmount[] calldata _idsAmounts, uint256 _extraBalance) external {
    (
      address payable[] memory tos,
      uint256[] memory amounts,
      uint256 total
    ) = _splitIdAndAmounts(_idsAmounts);

    _extraBalance = bound(_extraBalance, 0, type(uint256).max - total);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.deal(address(vault), total + _extraBalance);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.sendBatchETH(tos, amounts);
  }

  function test_fail_sendBatchETH_PermissionRemoved(IdAndAmount[] calldata _idsAmounts, uint256 _extraBalance) external {
    (
      address payable[] memory tos,
      uint256[] memory amounts,
      uint256 total
    ) = _splitIdAndAmounts(_idsAmounts);

    _extraBalance = bound(_extraBalance, 0, type(uint256).max - total);

    vault.delPermission(worker, sendPerm);

    vm.deal(address(vault), total + _extraBalance);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sendPerm));
    vault.sendBatchETH(tos, amounts);
  }

  function test_fail_sendBatchETH_NotWorker(address _notworker, IdAndAmount[] calldata _idsAmounts, uint256 _extraBalance) external {
    (
      address payable[] memory tos,
      uint256[] memory amounts,
      uint256 total
    ) = _splitIdAndAmounts(_idsAmounts);

    _notworker = boundDiff(_notworker, worker, address(this));
    _extraBalance = bound(_extraBalance, 0, type(uint256).max - total);

    vm.deal(address(vault), total + _extraBalance);

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, sendPerm));
    vault.sendBatchETH(tos, amounts);
  }

  function test_fail_sendBatchETH_NotEnoughBalance(IdAndAmount[] memory _idsAmounts, uint256 _missingBalance) public {
    (
      address payable[] memory tos,
      uint256[] memory amounts,
      uint256 total
    ) = _splitIdAndAmounts(_idsAmounts);

    vm.assume(amounts.length > 0);

    if (total == 0) {
      amounts[0] = 1;
      total = 1;
    }

    _missingBalance = bound(_missingBalance, 1, total);
    uint256 vaultBalance = total - _missingBalance;

    uint256 broken;
    uint256 rollingTotal;

    for (uint256 i = 0; i < tos.length; i++) {
      tos[i] = payable(boundDiff(tos[i], address(vault)));
      rollingTotal += amounts[i];
      if (rollingTotal > vaultBalance) {
        broken = i;
        break;
      }
    }

    vm.deal(address(vault), total - _missingBalance);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ErrorSendingETH(address,uint256,bytes)", tos[broken], amounts[broken], bytes('')));
    vault.sendBatchETH(tos, amounts);
  }

  /*
  [FAIL. Reason: Call did not revert as expected. Counterexample: calldata=0x90e23a960000000000000000000000000000000000000000000000000000000000000000001dae000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000049e300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c88000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000039c1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006f597075000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c880000000000000000000000000000000000000000000000000000000000000000000000000000000000ce71065d4017f316ec606fe4422e11eb2c47c246006ee1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f6d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000158c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004100000000000000000000000000000000000000000000000000000000000000000c8800000000000000000000000000000000000000000000000000000000000039c10000000000000000000000000000000000000000000000000000000000, args=[[(0x0000000000000000000000000000000000000000, 52439468742914703656929275041580839387723525970550597046124859052427051008), (0x0000000000000000000000000000000000000000, 130546532149543514039328407134969936433112726208602861690899145693163683840), (0x0000000000000000000000000000000000000000, 22140802280504128630090696806184697651463157582722600068961377709948141568), (0x0000000000000000000000000000000000000000, 102042319737298485597222865423765821314489646153539165218077920648872591360), (0x0000000000000000000000000000000000000000, 50364751731412445914540943927374232501809891820190298921797543259681591394304), (0x0000000000000000000000000000000000000000, 22140802280504128630090696806184697651463157582722600068961377709948141568), (0xce71065d4017f316ec606fe4422e11eb2c47c246, 195906070053650153106335545150733367467824728175056422368288250092543016960), (0x0000000000000000000000000000000000000000, 6977279058809839717524441830433785219002733908761819265622222888904555495424), (0x0000000000000000000000000000000000000000, 38070032848896749851490113336320072395720317090491852238276483618476916736), (0x0000000000000000000000000000000000000000, 29400335157912315244266070412362164103369332044010299463143527189509193072640)], 22140802280504128630090696806184697651463157582722600068961377709948141568, 102042319737298485597222865423765821314489646153539165218077920648872591360]]
  */

  function test_fail_sendBatchETH_Rejected(uint256 _amount, uint256 _balance, bytes calldata _reason) external {
    _amount = bound(_amount, 0, _balance);

    RejectsTransfer rt = new RejectsTransfer(_reason);

    vm.deal(address(vault), _balance);
    vm.prank(worker);

    bytes memory nestedErr = abi.encodeWithSignature("Reverted(bytes)", _reason);
    vm.expectRevert(abi.encodeWithSignature("ErrorSendingETH(address,uint256,bytes)", address(rt), _amount, nestedErr));

    address payable[] memory tos = new address payable[](1);
    uint256[] memory amounts = new uint256[](1);
    tos[0] = payable(rt);
    amounts[0] = _amount;

    vault.sendBatchETH(tos, amounts);
  }

  function test_fail_sendBatchETH_DiffSizeArray(uint256 _size1, uint256 _size2) external {
    _size1 = bound(_size1, 0, 10);
    _size2 = bound(_size2, 0, 10);
    _size1 = boundDiff(_size1, _size2);

    address payable[] memory tos = new address payable[](_size1);
    uint256[] memory amounts = new uint256[](_size2);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ArrayLengthMismatchETH(uint256,uint256)", _size1, _size2));
    vault.sendBatchETH(tos, amounts);
  }

  receive() external payable {}
}
