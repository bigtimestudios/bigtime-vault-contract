// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/VaultExecute.sol";

import "test/forge/AdvTest.sol";


contract VaultExecuteImp is VaultExecute {
  constructor (
    uint8 _executeOnReceiverPermission,
    uint8 _executePermission,
    uint8 _pausePermission
  ) VaultExecute(_executeOnReceiverPermission, _executePermission) Pausable(_pausePermission) {}
}

contract ExpectCall2 {
  bytes32 private immutable dataHash;
  uint256 private immutable amount;
  address private immutable from;

  error Rejected();

  constructor(
    address _from,
    uint256 _amount,
    bytes memory _data
  ) {
    dataHash = keccak256(_data);
    amount = _amount;
    from = _from;
  }

  receive() external payable {
    if (msg.value != amount) revert Rejected();
    if (msg.sender != from) revert Rejected();
  }

  fallback() external payable {
    if (msg.value != amount) revert Rejected();
    if (msg.sender != from) revert Rejected();
    if (keccak256(msg.data) != dataHash) revert Rejected();
  }
}

contract RejectsCall {
  error Rejected(address _from, uint256 _amount, bytes _data);

  receive() external payable {
    revert Rejected(msg.sender, msg.value, bytes(''));
  }

  fallback() external payable {
    revert Rejected(msg.sender, msg.value, msg.data);
  }
}

contract ReturnsOnCall {
  bytes private  val;

  constructor (bytes memory _val) {
    val = _val;
  }

  receive() external payable {
    _returnVal();
  }

  fallback() external payable {
    _returnVal();
  }

  function _returnVal() internal view {
    bytes memory v = val;
    assembly {
      return (add(v, 0x20), mload(v))
    }
  }
}

contract VaultExecuteTest is AdvTest {
  uint8 pausePerm = 0;
  uint8 executeReceiverPerm = 1;
  uint8 executePerm = 2;

  VaultExecuteImp vault;
  address worker;

  function setUp() external {
    vault = new VaultExecuteImp(executeReceiverPerm, executePerm, pausePerm);
    worker = vm.addr(1);

    vault.addPermission(worker, executeReceiverPerm);
    vault.addPermission(worker, executePerm);
  }

  //
  // Execute on receiver
  //

  function test_executeOnReceiver(
    uint256 _id,
    address payable _to,
    bytes memory _data
  ) public {
    _to = payable(boundNoSys(_to));

    vm.expectCall(_to, _data);
    vm.prank(worker);
    vault.executeOnReceiver(_id, _to, 0, _data);
  }

  function test_executeOnReceiver_replicate1() external {
    test_executeOnReceiver(
      4070815637249397495359917441711684260466522898401426079512180687778195963904,
      payable(address(0x00b4c79dab8f259c7aee6e5b2aa729821864227e84)),
      bytes(hex'000000000000000000000000ce71065d4017f316ec606fe4422e11eb2c47c246')
    );
  }

  function test_executeOnReceiver_ForwardReturn(
    uint256 _id,
    uint256 _value,
    bytes calldata _data,
    bytes calldata _return
  ) external {
    Receiver receiver = vault.receiverFor(_id);
    vm.deal(address(receiver), _value);

    ReturnsOnCall to = new ReturnsOnCall(_return);

    bytes memory res = vault.executeOnReceiver(_id, payable(to), _value, _data);
    assertEq(res, _return);
  }

  function test_executeOnReceiver_WithValue(
    uint256 _id,
    uint256 _balance,
    uint256 _amount,
    bytes calldata _data
  ) external {
    _amount = bound(_amount, 0, _balance);

    Receiver receiver = vault.receiverFor(_id);
    ExpectCall2 expectCall = new ExpectCall2(address(receiver), _amount, _data);

    vm.deal(address(receiver), _balance);

    vm.prank(worker);
    vault.executeOnReceiver(_id, payable(expectCall), _amount, _data);

    assertEq(address(expectCall).balance, _amount);
    assertEq(address(receiver).balance, _balance - _amount);
  }

  function test_fail_executeOnReceiver_NotPermitted(
    uint256 _id,
    address payable _to,
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    _to = payable(boundNoSys(_to));

    Receiver receiver = vault.receiverFor(_id);

    vm.deal(address(receiver), _balance);

    vault.delPermission(worker, executeReceiverPerm);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, executeReceiverPerm));
    vault.executeOnReceiver(_id, _to, _amount, _data);
  }

  function test_fail_executeOnReceiver_NotWorker(
    address _notworker,
    uint256 _id,
    address payable _to,
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    _to = payable(boundNoSys(_to));

    Receiver receiver = vault.receiverFor(_id);

    vm.deal(address(receiver), _balance);

    _notworker = boundDiff(_notworker, worker, address(this));

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, executeReceiverPerm));
    vault.executeOnReceiver(_id, _to, _amount, _data);
  }

  function test_fail_executeOnReceiver_Paused(
    uint256 _id,
    address payable _to,
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    _to = payable(boundNoSys(_to));

    Receiver receiver = vault.receiverFor(_id);

    vm.deal(address(receiver), _balance);

    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.executeOnReceiver(_id, _to, _amount, _data);
  }

  function test_fail_executeOnReceiver_CallRejected(
    uint256 _id,
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    RejectsCall rejectsCall = new RejectsCall();
    Receiver receiver = vault.receiverFor(_id);

    _amount = bound(_amount, 0, _balance);
    vm.deal(address(receiver), _balance);

    vm.prank(worker);
    bytes memory nestedErr = abi.encodeWithSignature("Rejected(address,uint256,bytes)", address(receiver), _amount, _data);
    bytes memory err = abi.encodeWithSignature(
      "ReceiverCallError(address,address,uint256,bytes,bytes)",
      receiver, rejectsCall, _amount, _data, nestedErr
    );
  
    vm.expectRevert(err);
    vault.executeOnReceiver(_id, payable(rejectsCall), _amount, _data);
  }

  //
  // Execute
  //

  function test_execute(
    address payable _to,
    uint256 _amount,
    bytes calldata _data
  ) external {
    _to = payable(boundNoSys(_to));

    vm.deal(address(vault), _amount);
    vm.prank(worker);
    vault.execute(_to, _amount, _data);
  }

  function test_execute_ForwardReturn(
    uint256 _amount,
    bytes calldata _data,
    bytes calldata _return
  ) external {
    ReturnsOnCall to = new ReturnsOnCall(_return);

    vm.deal(address(vault), _amount);
    bytes memory res = vault.execute(payable(to), _amount, _data);
    assertEq(res, _return);
  }

  function test_execute_WithValue(
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    _amount = bound(_amount, 0, _balance);

    vm.deal(address(vault), _balance);
    ExpectCall2 expectCall = new ExpectCall2(address(vault), _amount, _data);

    vm.prank(worker);
    vault.execute(payable(expectCall), _amount, _data);

    assertEq(address(expectCall).balance, _amount);
    assertEq(address(vault).balance, _balance - _amount);
  }

  function test_fail_execute_NotPermitted(
    address payable _to,
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    vm.deal(address(vault), _balance);
    vault.delPermission(worker, executePerm);

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", worker, executePerm));
    vault.execute(_to, _amount, _data);
  }

  function test_fail_execute_NotWorker(
    address _notworker,
    address payable _to,
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    _notworker = boundDiff(_notworker, worker, address(this));

    vm.deal(address(vault), _balance);

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature("PermissionDenied(address,uint8)", _notworker, executePerm));
    vault.execute(_to, _amount, _data);
  }

  function test_fail_execute_Paused(
    address payable _to,
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    vm.deal(address(vault), _balance);
    vault.addPermission(address(this), pausePerm);
    vault.pause();

    vm.prank(worker);
    vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
    vault.execute(_to, _amount, _data);
  }

  function test_fail_execute_CallRejected(
    uint256 _amount,
    uint256 _balance,
    bytes calldata _data
  ) external {
    _amount = bound(_amount, 0, _balance);

    RejectsCall rejectsCall = new RejectsCall();
    vm.deal(address(vault), _balance);

    vm.prank(worker);
    bytes memory nestedErr = abi.encodeWithSignature("Rejected(address,uint256,bytes)", address(vault), _amount, _data);
    bytes memory err = abi.encodeWithSignature(
      "CallError(address,uint256,bytes,bytes)",
      rejectsCall, _amount, _data, nestedErr
    );
  
    vm.expectRevert(err);
    vault.execute(payable(rejectsCall), _amount, _data);
  }
}
