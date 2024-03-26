// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/workers/ECDSAWorkerFactory.sol";

import "test/utils/ECDSA.t.sol";


contract ECDSAWorkerFactoryTest is AdvTest {
  ECDSAWorkerFactory private factory;

  function setUp() external {
    factory = new ECDSAWorkerFactory();
  }

  event CreatedWorker(address indexed _signer, address indexed _worker);

  function test_createWorkers(address _signer1, address _signer2) external {
    _signer2 = boundDiff(_signer2, address(0));
    _signer1 = boundDiff(_signer1, address(0));

    vm.expectEmit(true, true, true, true, address(factory));
    emit CreatedWorker(_signer1, address(factory.workerFor(_signer1)));
    ECDSAWorker worker1 = factory.createWorker(_signer1);

    ECDSAWorker worker2;
    if (_signer1 == _signer2) {
      vm.expectRevert();
      factory.createWorker(_signer2);
      worker2 = worker1;
    } else {

      vm.expectEmit(true, true, true, true, address(factory));
      emit CreatedWorker(_signer2, address(factory.workerFor(_signer2)));
      worker2 = factory.createWorker(_signer2);
    }

    assertEq(worker1.signer(), _signer1);
    assertEq(worker2.signer(), _signer2);

    assertEq(factory.workerFor(_signer1), address(worker1));
    assertEq(factory.workerFor(_signer2), address(worker2));
  }
}