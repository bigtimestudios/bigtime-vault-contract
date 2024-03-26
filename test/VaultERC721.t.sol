// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/VaultERC721.sol";
import "src/commons/token/MintableToken.sol";
import "src/interfaces/IERC721.sol";

import "solmate/tokens/ERC721.sol";

import "test/forge/AdvTest.sol";


contract VaultERC721Imp is VaultERC721 {
  constructor (
    uint8 _sendErc721Permission,
    uint8 _pausePermission
  ) VaultERC721(_sendErc721Permission) Pausable(_pausePermission) {}
}

contract ERC721Imp is ERC721 {
  constructor() ERC721("", "") {}

  function tokenURI(uint256) public view override virtual returns (string memory) {
    return "";
  }

  function mint(address _to, uint256 _val) external {
    _mint(_to, _val);
  }
}

contract VaultERC721Test is AdvTest {
  uint8 pausePerm = 0;
  uint8 sendPerm = 1;

  VaultERC721Imp vault;
  address worker;

  ERC721Imp token;

  function setUp() external {
    vault = new VaultERC721Imp(sendPerm, pausePerm);
    token = new ERC721Imp();

    worker = vm.addr(1);

    vault.addPermission(worker, sendPerm);
  }

  //
  // Send ERC721
  //

  function test_sendERC721(uint256 _from, address _to, uint256 _id) external {
    _to = boundDiff(boundDiff(boundNoSys(_to), address(token)), address(0));

    Receiver receiver = vault.receiverFor(_from);
    token.mint(address(receiver), _id);

    vm.prank(worker);
    vault.sendERC721(IERC721(address(token)), _from, _to, _id);
    assertEq(token.ownerOf(_id), _to);
  }

  function test_sendERC721Twice(uint256 _from, address _to1, address _to2, uint256 _id1, uint256 _id2) external {
    _to1 = boundDiff(boundDiff(boundNoSys(_to1), address(token)), address(0));
    _to2 = boundDiff(boundDiff(boundNoSys(_to2), address(token)), address(0));
    _id1 = boundDiff(_id1, _id2);

    Receiver receiver = vault.receiverFor(_from);
    token.mint(address(receiver), _id1);
    token.mint(address(receiver), _id2);

    vm.startPrank(worker);
    vault.sendERC721(IERC721(address(token)), _from, _to1, _id1);
    vault.sendERC721(IERC721(address(token)), _from, _to2, _id2);
    assertEq(token.ownerOf(_id1), _to1);
    assertEq(token.ownerOf(_id2), _to2);
  }

  function test_fail_sendERC712_NotOwnedByReceiver(uint256 _from, address _to, uint256 _id) external {
    vm.prank(worker);

    address receiver = address(vault.receiverFor(_from));

    vm.expectRevert(
      abi.encodeWithSignature(
        "ReceiverCallError(address,address,uint256,bytes,bytes)",
        receiver,
        address(token),
        0,
        abi.encodeWithSelector(token.transferFrom.selector, receiver, _to, _id),
        abi.encodeWithSignature("Error(string)", "WRONG_FROM")
      )
    );

    vm.prank(worker);
    vault.sendERC721(IERC721(address(token)), _from, _to, _id);
  }

  function test_fail_sendERC721_Paused(uint256 _from, address _to, uint256 _id) external {
    Receiver receiver = vault.receiverFor(_from);
    token.mint(address(receiver), _id);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vm.prank(worker);
    vault.sendERC721(IERC721(address(token)), _from, _to, _id);
  }

  function test_fail_sendERC721_NotPermitted(uint256 _from, address _to, uint256 _id) external {
    Receiver receiver = vault.receiverFor(_from);
    token.mint(address(receiver), _id);

    vault.delPermission(worker, sendPerm);

    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sendPerm));
    vm.prank(worker);
    vault.sendERC721(IERC721(address(token)), _from, _to, _id);
  }

  function test_fail_sendERC721_NotWorker(address _notworker, uint256 _from, address _to, uint256 _id) external {
    _notworker = boundDiff(_notworker, worker, address(this));

    Receiver receiver = vault.receiverFor(_from);
    token.mint(address(receiver), _id);

    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, sendPerm));
    vm.prank(_notworker);
    vault.sendERC721(IERC721(address(token)), _from, _to, _id);
  }

  //
  // Send ERC721 batch
  //

  struct FromToId {
    uint256 from;
    address to;
    uint256 id;
  }

  function splitFromToId(
    FromToId[] memory _formToIds
  ) internal returns (
    uint256[] memory _froms,
    address[] memory _tos,
    uint256[] memory _ids
  ) {
    uint256 size = mayBoundArr(_formToIds.length);

    _froms = new uint256[](size);
    _tos = new address[](size);
    _ids = new uint256[](size);

    for (uint256 i = 0; i < size; i++) {
      uint256 id = _formToIds[i].id;
      id = boundDiff(id, _ids);

      _ids[i] = id;
      _tos[i] = _formToIds[i].to;
      _froms[i] = _formToIds[i].from;

      Receiver receiver = vault.receiverFor(_froms[i]);
      token.mint(address(receiver), id);

      _tos[i] = boundDiff(boundDiff(boundNoSys(_tos[i]), address(token)), address(0));
    }
  }

  function test_sendBatchERC721(FromToId[] calldata _fromToIds) external {
    (
      uint256[] memory _froms,
      address[] memory _tos,
      uint256[] memory _ids
    ) = splitFromToId(_fromToIds);

    vm.prank(worker);
    vault.sendBatchERC721(IERC721(address(token)), _froms, _tos, _ids);
    for (uint256 i = 0; i < _froms.length; i++) {
      assertEq(token.ownerOf(_ids[i]), _tos[i]);
    }
  }

  function test_fail_sendBatchERC721_NotOwnedByReceiver(
    uint256 _from1,
    uint256 _from2,
    address _to1,
    address _to2,
    uint256 _id1,
    uint256 _id2,
    bool _missing1
  ) public {
    _to1 = boundDiff(boundDiff(boundNoSys(_to1), address(token)), address(0));
    _to2 = boundDiff(boundDiff(boundNoSys(_to2), address(token)), address(0));

    Receiver receiver1 = vault.receiverFor(_from1);
    Receiver receiver2 = vault.receiverFor(_from2);

    _to1 = boundDiff(_to1, address(receiver1), address(receiver2));
    _to2 = boundDiff(_to2, address(receiver1), address(receiver2));

    if (_missing1) {
      token.mint(address(receiver2), _id2);
    } else {
      token.mint(address(receiver1), _id1);
    }

    bool failsFirst = _missing1 && !(_id1 == _id2 && _from1 == _from2);

    Receiver mreceiver = failsFirst ? receiver1 : receiver2;
    address mto = failsFirst ? _to1 : _to2;
    uint256 mid = failsFirst ? _id1 : _id2;

    vm.expectRevert(
      abi.encodeWithSignature(
        "ReceiverCallError(address,address,uint256,bytes,bytes)",
        address(mreceiver),
        address(token),
        0,
        abi.encodeWithSelector(token.transferFrom.selector, address(mreceiver), mto, mid),
        abi.encodeWithSignature("Error(string)", "WRONG_FROM")
      )
    );

    uint256[] memory _froms = new uint256[](2);
    address[] memory _tos = new address[](2);
    uint256[] memory _ids = new uint256[](2);

    _froms[0] = _from1;
    _froms[1] = _from2;
    _tos[0] = _to1;
    _tos[1] = _to2;
    _ids[0] = _id1;
    _ids[1] = _id2;

    vm.prank(worker);
    vault.sendBatchERC721(IERC721(address(token)), _froms, _tos, _ids);
  }

  function test_fail_sendBatchERC721_Paused(FromToId[] calldata _fromToIds) external {
    (
      uint256[] memory _froms,
      address[] memory _tos,
      uint256[] memory _ids
    ) = splitFromToId(_fromToIds);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vm.prank(worker);
    vault.sendBatchERC721(IERC721(address(token)), _froms, _tos, _ids);
  }

  function test_fail_sendBatchERC721_NotPermitted(FromToId[] calldata _fromToIds) external {
    (
      uint256[] memory _froms,
      address[] memory _tos,
      uint256[] memory _ids
    ) = splitFromToId(_fromToIds);

    vault.delPermission(worker, sendPerm);

    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, sendPerm));
    vm.prank(worker);
    vault.sendBatchERC721(IERC721(address(token)), _froms, _tos, _ids);
  }

  function test_fail_sendBatchERC721_NotWorker(address _notworker, FromToId[] calldata _fromToIds) external {
    (
      uint256[] memory _froms,
      address[] memory _tos,
      uint256[] memory _ids
    ) = splitFromToId(_fromToIds);

    _notworker = boundDiff(_notworker, worker, address(this));

    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, sendPerm));
    vm.prank(_notworker);
    vault.sendBatchERC721(IERC721(address(token)), _froms, _tos, _ids);
  }

  function test_fail_sendBatchERC721_DiffSizeArrays(uint256 _size1, uint256 _size2, uint256 _size3) external {
    _size1 = bound(_size1, 0, 10);
    _size2 = bound(_size2, 0, 10);
    _size3 = bound(_size3, 0, 10);

    if (_size1 == _size2 && _size2 == _size3) {
      _size1++;
    }

    uint256[] memory _froms = new uint256[](_size1);
    address[] memory _tos = new address[](_size2);
    uint256[] memory _ids = new uint256[](_size3);

    vm.expectRevert(abi.encodeWithSignature("ArrayLengthMismatchERC721(uint256,uint256,uint256)", _size1, _size2, _size3));
    vm.prank(worker);
    vault.sendBatchERC721(IERC721(address(token)), _froms, _tos, _ids);
  }
}
