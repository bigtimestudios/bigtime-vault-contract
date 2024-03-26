// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/Permissions.sol";

import "test/forge/AdvTest.sol";


contract UsesPermissions is Permissions {
  uint8 expectPermission;
  uint256 public calls;

  function requestPermission(uint8 _permission) external {
    expectPermission = _permission;
  }

  function registerPermission(uint8 _permission) external {
    _registerPermission(_permission);
  }

  function stub() onlyPermissioned(expectPermission) external {
    calls++;
  }
}

contract PermissionsTest is AdvTest {
  UsesPermissions perm;

  function setUp() external {
    perm = new UsesPermissions();
  }

  function test_fail_CallerLacksPermission(address _caller, uint8 _permission) external {
    perm.requestPermission(_permission);
    vm.prank(_caller);
    if (_caller != address(this)) {
      vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _caller, _permission));
    }
    
    perm.stub();
    assertEq(perm.calls(), _caller != address(this) ? 0 : 1);
  }

  function test_callWithPermission(address _caller, uint8 _permission) external {
    perm.addPermission(_caller, _permission);
    perm.requestPermission(_permission);
    vm.prank(_caller);
    perm.stub();
    assertEq(perm.calls(), 1);
  }

  function test_callAsOwner(uint8 _permission) external {
    perm.requestPermission(_permission);
    perm.stub();
    assertEq(perm.calls(), 1);
  }

  function test_fail_callAsOwner_AddressZero(uint8 _permission) external {
    perm.rennounceOwnership();
    perm.requestPermission(_permission);
    vm.prank(address(0));
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", address(0), _permission));
    perm.stub();
  }

  function test_fail_callWithRemovedPermission(address _caller, uint8 _permission) external {
    perm.addPermission(_caller, _permission);
    perm.delPermission(_caller, _permission);
    perm.requestPermission(_permission);
    vm.prank(_caller);
    if (_caller != address(this)) {
      vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _caller, _permission));
    }
    perm.stub();
    assertEq(perm.calls(), _caller != address(this) ? 0 : 1);
  }

  function test_callWithTwoPermissions(address _caller, uint8 _permission1, uint8 _permission2) external {
    perm.addPermission(_caller, _permission1);
    perm.addPermission(_caller, _permission2);

    perm.requestPermission(_permission1);
    vm.prank(_caller);
    perm.stub();
    assertEq(perm.calls(), 1);

    perm.requestPermission(_permission2);
    vm.prank(_caller);
    perm.stub();
    assertEq(perm.calls(), 2);
  }

  function test_callAfterRemovingOnePermission(address _caller, uint8 _permission1, uint8 _permission2) external {
    _permission1 = uint8(boundDiff(_permission1, _permission2));

    perm.addPermission(_caller, _permission1);
    perm.addPermission(_caller, _permission2);

    perm.requestPermission(_permission1);
    vm.prank(_caller);
    perm.stub();
    assertEq(perm.calls(), 1);

    perm.delPermission(_caller, _permission1);

    perm.requestPermission(_permission2);
    vm.prank(_caller);
    perm.stub();
    assertEq(perm.calls(), 2);
  }

  function test_fail_AfterRemovingOnePermission(address _caller, uint8 _permission1, uint8 _permission2) external {
    _permission1 = uint8(boundDiff(_permission1, _permission2));

    perm.addPermission(_caller, _permission1);
    perm.addPermission(_caller, _permission2);

    perm.requestPermission(_permission1);
    vm.prank(_caller);
    perm.stub();
    assertEq(perm.calls(), 1);

    perm.delPermission(_caller, _permission2);

    perm.requestPermission(_permission2);
    vm.prank(_caller);
    if (_caller != address(this)) {
      vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _caller, _permission2));
    }
    perm.stub();
    assertEq(perm.calls(), _caller != address(this) ? 1 : 2);
  }

  function test_failAddPermissionNotOwner(address _imposter, address _to, uint8 _permission) external {
    _imposter = boundDiff(_imposter, address(this));

    vm.prank(_imposter);
    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _imposter, address(this)));
    perm.addPermission(_to, _permission);

    assertEq(perm.permissions(_to), 0);
  }

  function test_fail_DelPermissionNotOwner(address _imposter, address _to, uint8 _permission) external {
    perm.addPermission(_to, _permission);
    bytes32 prevPermissions = perm.permissions(_to);

    _imposter = boundDiff(_imposter, address(this));

    vm.prank(_imposter);
    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _imposter, address(this)));
    perm.delPermission(_to, _permission);

    assertEq(perm.permissions(_to), prevPermissions);
  }

  function test_addSamePermissionTwice(address _to, uint8 _permission) external {
    perm.addPermission(_to, _permission);
    bytes32 prevPermissions = perm.permissions(_to);

    perm.addPermission(_to, _permission);
    assertEq(perm.permissions(_to), prevPermissions);
  }

  function test_delNotExistingPermission(address _to, uint8 _permission) external {
    perm.delPermission(_to, _permission);
    assertEq(perm.permissions(_to), 0);
  }

  function test_addSamePermissionTwiceOnOccupied(address _to, uint8 _permission1, uint8 _permission2) external {
    perm.addPermission(_to, _permission1);

    perm.addPermission(_to, _permission2);
    bytes32 prevPermissions = perm.permissions(_to);

    perm.addPermission(_to, _permission2);
    assertEq(perm.permissions(_to), prevPermissions);
  }

  function test_delNotExistingPermissionOnOccupied(address _to, uint8 _permission1, uint8 _permission2) external {
    _permission1 = uint8(boundDiff(_permission1, _permission2));

    perm.addPermission(_to, _permission1);
    bytes32 prevPermissions = perm.permissions(_to);

    perm.delPermission(_to, _permission2);
    assertEq(perm.permissions(_to), prevPermissions);
  }

  function test_multipleAddressesSamePermission(address _to1, address _to2, uint8 _permission) external {
    _to1 = boundDiff(_to1, _to2, address(this));

    perm.requestPermission(_permission);
  
    perm.addPermission(_to1, _permission);
    vm.prank(_to1);
    perm.stub();
    assertEq(perm.calls(), 1);

    perm.addPermission(_to2, _permission);
    vm.prank(_to2);
    perm.stub();
    assertEq(perm.calls(), 2);

    perm.delPermission(_to1, _permission);
    vm.prank(_to1);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _to1, _permission));
    perm.stub();
    assertEq(perm.calls(), 2);

    perm.addPermission(_to2, _permission);
    vm.prank(_to2);
    perm.stub();
    assertEq(perm.calls(), 3);
  }

  function test_multipleAddressesDifferentPermissions(address _to1, address _to2, uint8 _permission1, uint8 _permission2) external {
    _to2 = boundDiff(_to2, address(this));
    _to1 = boundDiff(_to1, _to2, address(this));

    _permission1 = uint8(boundDiff(_permission1, _permission2));

    perm.addPermission(_to1, _permission1);
    perm.addPermission(_to2, _permission2);

    perm.requestPermission(_permission1);

    vm.prank(_to1);
    perm.stub();
    assertEq(perm.calls(), 1);

    vm.prank(_to2);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _to2, _permission1));
    perm.stub();
    assertEq(perm.calls(), 1);

    perm.requestPermission(_permission2);

    vm.prank(_to1);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _to1, _permission2));
    perm.stub();
    assertEq(perm.calls(), 1);

    vm.prank(_to2);
    perm.stub();
    assertEq(perm.calls(), 2);

    perm.delPermission(_to1, _permission1);

    vm.prank(_to2);
    perm.stub();
    assertEq(perm.calls(), 3);
  }

  event AddPermission(address indexed _owner, uint8 _permission);
  event DelPermission(address indexed _owner, uint8 _permission);
  event ClearPermissions(address indexed _owner);

  function test_emitEventAddPermission(address _to, uint8 _permission) external {
    vm.expectEmit(true, true, true, true, address(perm));
    emit AddPermission(_to, _permission);
    perm.addPermission(_to, _permission);
  }

  function test_emitEventDelPermission(address _to, uint8 _permission) external {
    perm.addPermission(_to, _permission);
    vm.expectEmit(true, true, true, true, address(perm));
    emit DelPermission(_to, _permission);
    perm.delPermission(_to, _permission);
  }

  function test_addPermissions(address _caller, uint8[] calldata _permissions) external {
    for (uint8 i = 0; i < _permissions.length; i++) {
      vm.expectEmit(true, true, true, true, address(perm));
      emit AddPermission(_caller, _permissions[i]);
    }

    perm.addPermissions(_caller, _permissions);

    bytes32 storageEntry;
    for (uint8 i = 0; i < _permissions.length; i++) {
      assertTrue(perm.hasPermission(_caller, _permissions[i]));

      perm.requestPermission(_permissions[i]);
      vm.prank(_caller);
      perm.stub();

      storageEntry |= bytes32(1 << _permissions[i]);
    }

    assertEq(perm.permissions(_caller), storageEntry);
  }

  function test_addPermissionsTwice(address _caller, uint8[] calldata _permissions1, uint8[] calldata _permissions2) external {
    perm.addPermissions(_caller, _permissions1);
    perm.addPermissions(_caller, _permissions2);

    bytes32 storageEntry;
    for (uint8 i = 0; i < _permissions1.length; i++) {
      assertTrue(perm.hasPermission(_caller, _permissions1[i]));
      storageEntry |= bytes32(1 << _permissions1[i]);
    }

    for (uint8 i = 0; i < _permissions2.length; i++) {
      assertTrue(perm.hasPermission(_caller, _permissions2[i]));
      storageEntry |= bytes32(1 << _permissions2[i]);
    }

    assertEq(perm.permissions(_caller), storageEntry);
  }

  function test_clearPermissions(address _caller, uint8[] calldata _permissions) external {
    perm.addPermissions(_caller, _permissions);

    vm.expectEmit(true, true, true, true, address(perm));
    emit ClearPermissions(_caller);
    perm.clearPermissions(_caller);

    for (uint8 i = 0; i < _permissions.length; i++) {
      assertFalse(perm.hasPermission(_caller, _permissions[i]));

      perm.requestPermission(_permissions[i]);
      if (_caller != address(this)) {
        vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _caller, _permissions[i]));
      }

      vm.prank(_caller);
      perm.stub();
    }

    assertEq(perm.permissions(_caller), bytes32(0));
  }

  function test_clearPermissions_replicate1() external {
    replicate(bytes(hex'2a6023ba000000000000000000000000b4c79dab8f259c7aee6e5b2aa729821864227e840000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000007b0000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000000000000000000000000000000000000002d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006200000000000000000000000000000000000000000000000000000000000000720000000000000000000000000000000000000000000000000000000000000084000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000084000000000000000000000000000000000000000000000000000000000000008400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000000000000000000000000000000000000004600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006c0000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000006c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000008400000000000000000000000000000000000000000000000000000000000000840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002d000000000000000000000000000000000000000000000000000000000000007200000000000000000000000000000000000000000000000000000000000000720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002d0000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002d000000000000000000000000000000000000000000000000000000000000006200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000006c00000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000072000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003800000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004600000000000000000000000000000000000000000000000000000000000000620000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000000000000000000000000000000000000008400000000000000000000000000000000000000000000000000000000000000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000002d00000000000000000000000000000000000000000000000000000000000000840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000002d0000000000000000000000000000000000000000000000000000000000000084000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000840000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062'));
  }

  function test_fail_addPermissionsNotOwner(address _imposter, address _to, uint8[] calldata _permissions) external {
    _imposter = boundDiff(_imposter, address(this));

    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _imposter, address(this)));
    vm.prank(_imposter);
    perm.addPermissions(_to, _permissions);
  }

  function test_fail_clearPermissionsNotOwner(address _imposter, address _to) external {
    _imposter = boundDiff(_imposter, address(this));

    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _imposter, address(this)));
    vm.prank(_imposter);
    perm.clearPermissions(_to);
  }

  function test_registerPermission(uint8 _permission) external {
    perm.registerPermission(_permission);
    assertEq(perm.permissionExists(_permission), true);
  }

  function test_registerPermission_Two(uint8 _permission1, uint8 _permission2) external {
    _permission1 = uint8(boundDiff(_permission1, _permission2));
    perm.registerPermission(_permission1);
    perm.registerPermission(_permission2);
    assertEq(perm.permissionExists(_permission1), true);
    assertEq(perm.permissionExists(_permission2), true);
  }

  function test_fail_registerPermission_twice(uint8 _permission) external {
    perm.registerPermission(_permission);
    vm.expectRevert(abi.encodeWithSignature("DuplicatedPermission(uint8)", _permission));
    perm.registerPermission(_permission);
  }
}
