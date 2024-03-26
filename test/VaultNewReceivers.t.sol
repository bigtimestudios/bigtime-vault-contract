// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/VaultNewReceivers.sol";

import "test/forge/AdvTest.sol";


contract VaultNewReceiversImp is VaultNewReceivers {
  constructor (
    uint8 _deployReceiverPermission,
    uint8 _pausePermission
  ) VaultNewReceivers(_deployReceiverPermission) Pausable(_pausePermission) {}
}

contract VaultNewReceiversTest is AdvTest {
  uint8 pausePerm = 0;
  uint8 deployPerm = 1;

  VaultNewReceiversImp vault;
  address worker;

  function setUp() external {
    vault = new VaultNewReceiversImp(deployPerm, pausePerm);

    worker = vm.addr(deployPerm);
    vault.addPermission(worker, deployPerm);
  }

  function test_deployReceivers(uint256 _id) external {
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _id;

    vm.prank(worker);
    vault.deployReceivers(_ids);

    Receiver receiver = vault.receiverFor(_id);
    assertTrue(address(receiver).code.length > 0);
  }

  function test_deployReceivers_Array(uint256[] memory _ids) external {
    _ids = mayBoundArr(_ids);

    vm.prank(worker);
    vault.deployReceivers(_ids);

    for (uint256 i = 0; i < _ids.length; i++) {
      Receiver receiver = vault.receiverFor(_ids[i]);
      assertTrue(address(receiver).code.length > 0);
    }
  }

  function test_deployReceivers_Array_Fail_NotWorker(address _notworker, uint256[] calldata _ids) external {
    _notworker = boundDiff(_notworker, worker, address(this));

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, deployPerm));
    vault.deployReceivers(mayBoundArr(_ids));
  }

  function test_deployReceivers_Array_Fail_Paused(uint256[] calldata _ids) external {
    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.deployReceivers(mayBoundArr(_ids));
  }

  function test_deployReceivers_Range(uint256 _start, uint256 _size) external {
    _size = bound(_size, 0, min(type(uint256).max - _start, 256));

    uint256 end = _start + _size;

    vm.prank(worker);
    vault.deployReceiversRange(_start, end);

    for (uint256 i = _start; i < end; i++) {
      assertTrue(address(vault.receiverFor(i)).code.length > 0);
    }

    assertTrue(address(vault.receiverFor(end)).code.length == 0);
  }

  function test_deployReceivers_Range_Negative(uint256 _start, uint256 _end) external {
    _end = bound(_end, 0, _start);

    vm.prank(worker);
    vault.deployReceiversRange(_start, _end);
  }

  function test_deployReceivers_Array_Fail_NotWorker(address _notworker, uint256 _from, uint256 _to) external {
    _notworker = boundDiff(_notworker, worker, address(this));

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, deployPerm));
    vault.deployReceiversRange(_from, _to);
  }

  function test_deployReceivers_Array_Fail_Paused(uint256 _from, uint256 _to) external {
    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.deployReceiversRange(_from, _to);
  }
}
