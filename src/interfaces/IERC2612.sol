// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;


interface IERC2612 {
  function permit(address _owner, address _spender, uint _value, uint _deadline, uint8 _v, bytes32 _r, bytes32 _s) external;
  function nonces(address _owner) external view returns (uint);
  function DOMAIN_SEPARATOR() external view returns (bytes32);
}
