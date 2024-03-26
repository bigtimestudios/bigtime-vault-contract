// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/token/Token.sol";

import "src/interfaces/IERC2612.sol";


contract TokenPermit is Token, IERC2612 {
  error ExpiredPermit(address _owner, address _spender, uint256 _value, uint256 _deadline);
  error InvalidPermitSignature(address _owner, address _spender, uint256 _value, uint256 _nonce, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s);
  error InvalidPermitOwner(address _owner);

  mapping(address => uint256) public nonces;

  uint256 private immutable INITIAL_CHAIN_ID;
  bytes32 private immutable INITIAL_DOMAIN_SEPARATOR;

  bytes32 private immutable NAME_HASH;
  bytes32 private immutable VERSION_HASH;

  constructor (string memory _name, string memory _symbol, uint8 _decimals) Token(_name, _symbol, _decimals) {
    NAME_HASH = keccak256(bytes(_name));
    VERSION_HASH = keccak256(bytes('1'));

    INITIAL_CHAIN_ID = block.chainid;
    INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
  }

  function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
  }

  function _computeDomainSeparator() private view returns (bytes32) {
    return keccak256(
      abi.encode(
        keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        NAME_HASH,
        VERSION_HASH,
        block.chainid,
        address(this)
      )
    );
  }

  function permit(address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external {
    if (_deadline < block.timestamp) {
      revert ExpiredPermit(_owner, _spender, _value, _deadline);
    }

    if (_owner == address(0)) {
      revert InvalidPermitOwner(_owner);
    }

    uint256 nonce = nonces[_owner];

    unchecked {
      nonces[_owner] = nonce + 1;
    }

    bytes32 digest = keccak256(
      abi.encodePacked(
        hex"1901",
        DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            _owner,
            _spender,
            _value,
            nonce,
            _deadline
          )
        )
      )
    );

    if (ecrecover(digest, _v, _r, _s) != _owner) {
      revert InvalidPermitSignature(_owner, _spender, _value, nonce, _deadline, _v, _r, _s);
    }

    _approve(_owner, _spender, _value);
  }
}
