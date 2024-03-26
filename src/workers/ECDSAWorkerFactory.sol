// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/workers/ECDSAWorker.sol";


contract ECDSAWorkerFactory {
  event CreatedWorker(address indexed _signer, address indexed _worker);

  function createWorker(address _signer) external returns (ECDSAWorker) {
    ECDSAWorker worker = new ECDSAWorker{ salt: 0 }(_signer);
    emit CreatedWorker(_signer, address(worker));
    return worker;
  }

  function workerFor(address _signer) external view returns (address) {
    return address(uint160(uint(keccak256(abi.encodePacked(
      bytes1(0xff),
      address(this),
      bytes32(0),
      keccak256(
        abi.encodePacked(
          type(ECDSAWorker).creationCode,
          abi.encode(_signer)
        )
      )
    )))));
  }
}
