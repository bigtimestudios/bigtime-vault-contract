// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/Permissions.sol";
import "src/commons/token/MintableToken.sol";
import "src/commons/token/Token.sol";


contract TokenFactory is Permissions {
  uint8 public immutable createTokenPerm;

  event CreatedFixedSupplyToken(
    address indexed _token,
    string _name,
    string _symbol,
    uint256 _supply,
    address _recipient
  );

  event CreatedMintableToken(
    address indexed _token,
    string _name,
    string _symbol,
    address _owner
  );

  constructor(uint8 _createTokenPerm) {
    createTokenPerm = _createTokenPerm;
  }

  function createFixedSupplyToken(
    string calldata _name,
    string calldata _symbol,
    uint8 _decimals,
    uint256 _supply,
    address _recipient
  ) external onlyPermissioned(createTokenPerm) returns (Token) {
    MintableToken token = new MintableToken(_name, _symbol, _decimals);

    token.mint(_recipient, _supply);
    token.disableMinting();
    token.rennounceOwnership();

    emit CreatedFixedSupplyToken(address(token), _name, _symbol, _supply, _recipient);

    return token;
  }

  function createMintableToken(
    string calldata _name,
    string calldata _symbol,
    uint8 _decimals,
    address _owner
  ) external onlyPermissioned(createTokenPerm) returns (MintableToken) {
    MintableToken token = new MintableToken(_name, _symbol, _decimals);

    token.transferOwnership(_owner);

    emit CreatedMintableToken(address(token), _name, _symbol, _owner);

    return token;
  }
}
