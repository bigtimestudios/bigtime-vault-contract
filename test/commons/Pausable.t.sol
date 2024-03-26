// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/Pausable.sol";

import "test/forge/AdvTest.sol";


contract PausableMock is Pausable {
  constructor(uint8 _permission) Pausable(_permission) { }

  function failsOnPaused() notPaused external view returns (bool) {
    return true;
  }

  function independent() external pure returns (bool) {
    return true;
  }
}

contract PausableTest is AdvTest {
  event Unpaused(address _sender);
  event Paused(address _sender);

  uint8 permission = 2;
  PausableMock pausable;
  address pauser;

  function setUp() external {
    pauser = vm.addr(1);
    pausable = new PausableMock(permission);
    pausable.addPermission(pauser, permission);
  }

  function test_startUnpaused() external {
    assertEq(pausable.isPaused(), false);
    pausable.failsOnPaused();
  }

  function test_pause() external {
    vm.prank(pauser);
    pausable.pause();

    assertEq(pausable.isPaused(), true);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    pausable.failsOnPaused();
  }

  function test_unpause() external {
    vm.prank(pauser);
    pausable.pause();

    pausable.unpause();

    assertEq(pausable.isPaused(), false);
    pausable.failsOnPaused();
  }

  function test_independentOnPaused() external {
    vm.prank(pauser);
    pausable.pause();

    pausable.independent();
  }

  function test_independentOnUnpaused() external view { 
    pausable.independent();
  }

  function test_failPauseIfNotPermissioned() external {
    address imposter = vm.addr(2);
    vm.prank(imposter);

    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", imposter, permission));
    pausable.pause();
  }

  function test_failUnpauseByPauser() external {
    vm.prank(pauser);
    pausable.pause();

    vm.prank(pauser);
    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", pauser, address(this)));
    pausable.unpause();
  }

  function test_pauseTwice() external {
    vm.prank(pauser);
    pausable.pause();
    vm.prank(pauser);
    pausable.pause();

    assertEq(pausable.isPaused(), true);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    pausable.failsOnPaused();
  }

  function test_unpauseNotPaused() external {
    pausable.unpause();
    assertEq(pausable.isPaused(), false);
    pausable.failsOnPaused();
  }

  function test_emitPauseEvent() external {
    vm.prank(pauser);
    vm.expectEmit(true, true, true, true, address(pausable));
    emit Paused(address(pauser));
    pausable.pause();
  }

  function test_emitUnpausedEvent() external {
    vm.prank(pauser);
    pausable.pause();

    vm.expectEmit(true, true, true, true, address(pausable));
    emit Unpaused(address(this));
    pausable.unpause();
  }
}
