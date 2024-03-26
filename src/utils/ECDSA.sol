// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;


library ECDSA {
  function recover(
    bytes32 _hash,
    bytes calldata _signature
  ) internal pure returns (address) {
    bytes32 r; bytes32 s; uint8 v;
    assembly {
      r := calldataload(_signature.offset)
      s := calldataload(add(_signature.offset, 32))
      v := and(calldataload(add(_signature.offset, 33)), 0xff)
    }

    return ecrecover(_hash, v, r, s);
  }
}
