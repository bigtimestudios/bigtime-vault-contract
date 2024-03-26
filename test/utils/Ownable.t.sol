// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/Ownable.sol";

import "test/forge/AdvTest.sol";


contract OwnableTest is AdvTest {
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  Ownable ownable;

  function setUp() external {
    ownable = new Ownable();
  }

  modifier notOwner(address _addr) {
    vm.assume(_addr != address(this));
    _;
  }

  function test_createOwnable() external {
    vm.expectEmit(true, true, true, true);
    emit OwnershipTransferred(address(0), address(this));

    Ownable ownable2 = new Ownable();

    assertEq(ownable2.owner(), address(this));
  }

  function test_bad_transferOwnership(address _notOwner, address _newOwner) notOwner(_notOwner) external {
    vm.prank(_notOwner);
    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _notOwner, address(this)));
    ownable.transferOwnership(_newOwner);
  }

  function test_bad_renounceOwnership(address _notOwner) notOwner(_notOwner)  external {
    vm.prank(_notOwner);
    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _notOwner, address(this)));
    ownable.rennounceOwnership();
  }

  function test_bad_newOwner() public {
    vm.expectRevert(abi.encodeWithSignature("InvalidNewOwner()"));
    ownable.transferOwnership(address(0));
  }

  function test_transferOwnership(address _newOwner) external {
    vm.assume(_newOwner != address(0));

    vm.expectEmit(true, true, true, true);
    emit OwnershipTransferred(address(this), _newOwner);

    ownable.transferOwnership(_newOwner);

    assertEq(ownable.owner(), _newOwner);
  }

  function test_rennounceOwnership() external {
    vm.expectEmit(true, true, true, true);
    emit OwnershipTransferred(address(this), address(0));

    ownable.rennounceOwnership();

    assertEq(ownable.owner(), address(0));
  }

  function test_bad_transferOwnership_after_rennounce(address _notOwner, address _newOwner) notOwner(_notOwner)  external {
    ownable.rennounceOwnership();

    vm.prank(_notOwner);
    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _notOwner, address(0)));
    ownable.transferOwnership(_newOwner);
  }
}
