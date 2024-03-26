// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/token/MintableToken.sol";

import "test/forge/AdvTest.sol";


contract MintableTokenTest is AdvTest {
  MintableToken token;

  function setUp() external {
    token = new MintableToken("", "", 0);
  }

  function test_passMetadata(string calldata _name, string calldata _symbol, uint8 _decimals) external {
    token = new MintableToken(_name, _symbol, _decimals);
    assertEq(token.name(), _name);
    assertEq(token.symbol(), _symbol);
    assertEq(token.decimals(), _decimals);
  }

  function test_mintTokens(address _to, uint256 _amount) external {
    _to = boundDiff(_to, address(token));
    assertTrue(token.mint(_to, _amount));
    assertEq(token.balanceOf(_to), _amount);
    assertEq(token.totalSupply(), _amount);
  }

  function test_mintTokensTwice(address _to1, address _to2, uint256 _amount1, uint256 _amount2) external {
    _to1 = boundDiff(_to1, address(token));
    _to2 = boundDiff(_to2, address(token));
    _to1 = boundDiff(_to1, _to2);

    _amount2 = bound(_amount2, 0, type(uint256).max - _amount1);

    assertTrue(token.mint(_to1, _amount1));
    assertTrue(token.mint(_to2, _amount2));

    assertEq(token.balanceOf(_to1), _amount1);
    assertEq(token.balanceOf(_to2), _amount2);
    assertEq(token.totalSupply(), _amount1 + _amount2);
  }

  function test_mintTokensTwiceToSame(address _to, uint256 _amount1, uint256 _amount2) external {
    _to = boundDiff(_to, address(token));
    _amount2 = bound(_amount2, 0, type(uint256).max - _amount1);

    assertTrue(token.mint(_to, _amount1));
    assertTrue(token.mint(_to, _amount2));

    assertEq(token.balanceOf(_to), _amount1 + _amount2);
    assertEq(token.totalSupply(), _amount1 + _amount2);
  }

  function test_fail_mintTokensNotOwner(address _sender, address _to, uint256 _amount) external {
    _sender = boundDiff(_sender, address(this));

    uint256 prevBalance = token.balanceOf(_to);

    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _sender, address(this)));
    vm.prank(_sender);
    token.mint(_to, _amount);

    assertEq(token.balanceOf(_to), prevBalance);
  }

  function test_fail_mintTokensOverflow(address _to1, address _to2, uint256 _amount1, uint256 _amount2) external {
    _to1 = boundDiff(_to1, address(token));
    _to2 = boundDiff(_to2, address(token));

    _amount1 = bound(_amount1, 1, type(uint256).max);
    _amount2 = bound(_amount2, type(uint256).max - _amount1 + 1, type(uint256).max);

    token.mint(_to1, _amount1);

    vm.expectRevert(stdError.arithmeticError);
    token.mint(_to2, _amount2);
  }

  event Transfer(address indexed from, address indexed to, uint256 value);

  function test_emitEventOnMint(address _to, uint256 _amount) external {
    _to = boundDiff(_to, address(token));

    vm.expectEmit(true, true, true, true, address(token));
    emit Transfer(address(0), _to, _amount);
    token.mint(_to, _amount);
  }

  function test_startMintingEnabled() external {
    assertTrue(token.mintingEnabled());
  }

  function test_disableMinting() external {
    assertTrue(token.disableMinting());
    assertFalse(token.mintingEnabled());
  }

  event MintingEnded(address _sender);

  function test_emitEventOnDisableMinting() external {
    vm.expectEmit(true, true, true, true, address(token));
    emit MintingEnded(address(this));
    token.disableMinting();
  }

  function test_failDisableMintingNotOwner(address _sender) external {
    _sender = boundDiff(_sender, address(this));
    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _sender, address(this)));
    vm.prank(_sender);
    token.disableMinting();
  }

  function test_fail_disableMintingTwice() external {
    token.disableMinting();
    vm.expectRevert(abi.encodeWithSignature("MintingDisabled()"));
    token.disableMinting();
  }

  function test_fail_mintAfterDisabled(address _to, uint256 _amount) external {
    token.disableMinting();
    vm.expectRevert(abi.encodeWithSignature("MintingDisabled()"));
    token.mint(_to, _amount);
  }

  function test_fail_mintAfterDisabledNotOwner(address _sender, address _to, uint256 _amount) external {
    _sender = boundDiff(_sender, address(this));

    token.disableMinting();
    vm.expectRevert(abi.encodeWithSignature("NotOwner(address,address)", _sender, address(this)));
    vm.prank(_sender);
    token.mint(_to, _amount);
  }
}
