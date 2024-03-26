// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/utils/Proxy.sol";
import "src/libs/CREATE2.sol";

import "test/forge/AdvTest.sol";


contract ImplementationMock {
  bool immutable revertOnCall;
  error RevertByRequest(bytes32 _err);

  constructor (bool _revertOnCall) {
    revertOnCall = _revertOnCall;
  }

  fallback() external payable {
    if (revertOnCall) {
      revert RevertByRequest(keccak256(msg.data));
    }
  }
}

contract ProxyTest is AdvTest {
  function setUp() external { }

  function test_createProxy(uint256 _salt, address _target) external {
    address real = CREATE2.deploy(_salt, Proxy.creationCode(_target));

    assertEq(real, CREATE2.addressOf(address(this), _salt, keccak256(Proxy.creationCode(_target))));
    assertTrue(address(real).code.length != 0);
  }

  function test_passCallToTarget(uint256 _salt, address _target, bytes calldata _data) external {
    _target = boundNoSys(_target);

    vm.assume(_target != address(0) && _target != address(this));
    address expected = CREATE2.addressOf(address(this), _salt, keccak256(Proxy.creationCode(_target)));
    vm.assume(_target != expected);

    CREATE2.deploy(_salt, Proxy.creationCode(_target));
    vm.expectCall(expected, abi.encodePacked(_data));

    (bool res,) = expected.call(_data);
    assertTrue(res);
  }

  function test_receiveETH(uint256 _salt, uint256 _amount) external {
    address imp = address(new ImplementationMock(false));

    vm.deal(address(this), _amount);
    address proxy = CREATE2.deploy(_salt, Proxy.creationCode(imp));

    payable(proxy).transfer(_amount);
    assertEq(proxy.balance, _amount);
  }

  function test_bubbleUpRevert(uint256 _salt, bytes calldata _data) external {
    address imp = address(new ImplementationMock(true));
    address proxy = CREATE2.deploy(_salt, Proxy.creationCode(imp));

    (bool res, bytes memory err) = proxy.call(_data);

    assertFalse(res);
    assertEq(err, abi.encodeWithSignature("RevertByRequest(bytes32)", keccak256(_data)));
  }

  function test_rejectETH(uint256 _salt, uint256 _amount, bytes calldata _data) external {
    address imp = address(new ImplementationMock(true));
    address proxy = CREATE2.deploy(_salt, Proxy.creationCode(imp));

    (bool res,) = payable(proxy).call{ value: _amount }(_data);

    assertFalse(res);
    assertEq(proxy.balance, 0);
  }
}
