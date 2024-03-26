// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/utils/ECDSA.sol";

import "test/forge/AdvTest.sol";


contract ECDSAImp {
  function recover(
    bytes32 _hash,
    bytes calldata _signature,
    bytes calldata
  ) external pure returns (address) {
    return ECDSA.recover(_hash, _signature);
  }
}

contract ECDSATest is AdvTest {
  ECDSAImp ecdsa;

  function setUp() external {
    ecdsa = new ECDSAImp();
  }

  function test_recoverSignature(uint256 _pk, bytes32 _hash, bytes calldata _ecd) external {
    _pk = boundPk(_pk);

    address signer = vm.addr(_pk);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, _hash);

    address recovered = ecdsa.recover(_hash, abi.encodePacked(r, s, v), _ecd);
    assertEq(recovered, signer);
  }
}
