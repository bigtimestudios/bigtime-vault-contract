// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/token/TokenFactory.sol";
import "src/commons/token/MintableToken.sol";

import "test/forge/AdvTest.sol";


contract TokenFactoryTest is AdvTest {
  TokenFactory factory;

  address worker;

  constructor() {
    factory = new TokenFactory(0);
    worker = vm.addr(1);
    factory.addPermission(worker, 0);
  }

  event CreatedFixedSupplyToken(
    address indexed _token,
    string _name,
    string _symbol,
    uint256 _supply,
    address _recipient
  );

  function test_createFixedSupplyToken(
    string calldata _name,
    string calldata _symbol,
    uint8 _decimals,
    uint256 _supply,
    address _recipient,
    uint256 _tryMint,
    address _tryMintBy,
    address _tryMintTo
  ) external {
    address expectedTokenAddr = computeCreateAddress(address(factory), vm.getNonce(address(factory)));

    _recipient = boundDiff(_recipient, expectedTokenAddr);

    vm.prank(worker);
    vm.expectEmit(true, true, true, true, address(factory));
    emit CreatedFixedSupplyToken(expectedTokenAddr, _name, _symbol, _supply, _recipient);
    Token token = factory.createFixedSupplyToken(_name, _symbol, _decimals, _supply, _recipient);

    assertEq(address(token), expectedTokenAddr);
    assertEq(token.balanceOf(_recipient), _supply);
    assertEq(token.totalSupply(), _supply);
    assertEq(token.name(), _name);
    assertEq(token.symbol(), _symbol);
    assertEq(token.decimals(), _decimals);
    assertEq(MintableToken(address(token)).owner(), address(0));
    assertFalse(MintableToken(address(token)).mintingEnabled());

    vm.prank(_tryMintBy);
    vm.expectRevert(abi.encodeWithSignature('NotOwner(address,address)', _tryMintBy, address(0)));
    MintableToken(address(token)).mint(_tryMintTo, _tryMint);
  }

  function test_fail_createFixedSupplyToken_NotWorker(
    string calldata _name,
    string calldata _symbol,
    uint8 _decimals,
    uint256 _supply,
    address _recipient,
    address _notworker
  ) external {
    _notworker = boundDiff(_notworker, worker, address(this));

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature('PermissionDenied(address,uint8)', _notworker, 0));
    factory.createFixedSupplyToken(_name, _symbol, _decimals, _supply, _recipient);
  }

  event CreatedMintableToken(
    address indexed _token,
    string _name,
    string _symbol,
    address _owner
  );

  function test_createMintableToken(
    string calldata _name,
    string calldata _symbol,
    uint8 _decimals,
    address _owner,
    uint256 _tryMint,
    address _tryMintTo
  ) external {
    _owner = boundDiff(_owner, address(0));

    address expectedTokenAddr = computeCreateAddress(address(factory), vm.getNonce(address(factory)));

    vm.prank(worker);
    vm.expectEmit(true, true, true, true, address(factory));
    emit CreatedMintableToken(expectedTokenAddr, _name, _symbol, _owner);
    Token token = factory.createMintableToken(_name, _symbol, _decimals, _owner);

    assertEq(address(token), expectedTokenAddr);
    assertEq(token.balanceOf(_owner), 0);
    assertEq(token.totalSupply(), 0);
    assertEq(token.name(), _name);
    assertEq(token.symbol(), _symbol);
    assertEq(token.decimals(), _decimals);
    assertEq(MintableToken(address(token)).owner(), _owner);
    assertTrue(MintableToken(address(token)).mintingEnabled());

    _tryMintTo = boundDiff(_tryMintTo, address(token));

    vm.prank(_owner);
    MintableToken(address(token)).mint(_tryMintTo, _tryMint);

    assertEq(token.balanceOf(_tryMintTo), _tryMint);
    assertEq(token.totalSupply(), _tryMint);
  }

  function test_fail_createMintableToken_NotWorker(
    string calldata _name,
    string calldata _symbol,
    uint8 _decimals,
    address _owner,
    address _notworker
  ) external {
    _notworker = boundDiff(_notworker, worker, address(this));

    vm.prank(_notworker);
    vm.expectRevert(abi.encodeWithSignature('PermissionDenied(address,uint8)', _notworker, 0));
    factory.createMintableToken(_name, _symbol, _decimals, _owner);
  }
}
