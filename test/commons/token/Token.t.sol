// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/token/Token.sol";

import "test/forge/AdvTest.sol";


contract ImpToken is Token {
  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals
  ) Token(_name, _symbol, _decimals) {}
  
  function mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }

  function mintWithoutIncreasingSupply(address _to, uint256 _amount) external {
    if (totalSupply >= _amount) {
      totalSupply -= _amount;
      _mint(_to, _amount);
    } else {
      _mint(_to, _amount);
      totalSupply -= _amount;
    }
  }
}


contract TokenTest is AdvTest {
  ImpToken token;

  function setUp() external {
    token = new ImpToken('', '', 18);
  }

  function test_transfer(address _from, address _to, uint256 _balance, uint256 _amount) external {
    _to = boundDiff(_to, _from);

    _amount = bound(_amount, 0, _balance);

    token.mint(_from, _balance);

    vm.prank(_from);
    assertTrue(token.transfer(_to, _amount));

    assertEq(token.balanceOf(_from), _balance - _amount);
    assertEq(token.balanceOf(_to), _amount);
  }

  function test_fail_TransferIfNotEnoughBalance(address _from, address _to, uint256 _balance, uint256 _amount) public {
    _balance = boundDiff(_balance, type(uint256).max);

    _amount = bound(_amount, _balance + 1, type(uint256).max);

    token.mint(_from, _balance);

    vm.prank(_from);
    vm.expectRevert(abi.encodeWithSignature("NotEnoughBalance(address,uint256,uint256)", _from, _balance, _amount));
    token.transfer(_to, _amount);
  }

  function test_transferToSelf(address _from, uint256 _balance, uint256 _amount) external {
    _from = boundDiff(_from, address(token));

    token.mint(_from, _balance);

    if (_amount > _balance) {
      vm.expectRevert(abi.encodeWithSignature("NotEnoughBalance(address,uint256,uint256)", _from, _balance, _amount));
    }

    vm.prank(_from);
    token.transfer(_from, _amount);

    assertEq(token.balanceOf(_from), _balance);
  }

  function test_transfer_zero(address _from, address _to) external {
    vm.prank(_from);
    assertTrue(token.transfer(_to, 0));
    assertEq(token.balanceOf(_from), 0);
    assertEq(token.balanceOf(_to), 0);
  }

  function test_setAllowance(address _spender, address _from, uint256 _amount) external {
    vm.prank(_from);
    assertTrue(token.approve(_spender, _amount));
    assertEq(token.allowance(_from, _spender), _amount);
  }

  function test_changeAllowance(address _spender, address _from, uint256 _allowance1, uint256 _allowance2) external {
    vm.startPrank(_from);
    assertTrue(token.approve(_spender, _allowance1));
    assertTrue(token.approve(_spender, _allowance2));
    assertEq(token.allowance(_from, _spender), _allowance2);
  }

  function test_setMultipleAllowances(address _from, address _spender1, address _spender2, uint256 _allowance1, uint256 _allowance2) external {
    _spender1 = boundDiff(_spender1, _spender2);

    vm.startPrank(_from);
    assertTrue(token.approve(_spender1, _allowance1));
    assertTrue(token.approve(_spender2, _allowance2));
    assertEq(token.allowance(_from, _spender1), _allowance1);
    assertEq(token.allowance(_from, _spender2), _allowance2);
  }

  function test_transferFromToSelf(address _spender, address _from, uint256 _balance, uint256 _allowance, uint256 _amount) external {
    _amount = bound(_amount, 0, _balance);
    _allowance = bound(_allowance, _amount, type(uint256).max);

    token.mint(_from, _balance);

    vm.prank(_from);
    assertTrue(token.approve(_spender, _allowance));

    vm.prank(_spender);
    assertTrue(token.transferFrom(_from, _from, _amount));

    assertEq(token.balanceOf(_from), _balance);
    assertEq(token.allowance(_from, _spender), _allowance != type(uint256).max ? _allowance - _amount : _allowance);
  }

  function test_transferFromToSelfUsingSelf(address _from, uint256 _balance, uint256 _allowance, uint256 _amount) external {
    _amount = bound(_amount, 0, _balance);
    _allowance = bound(_allowance, _amount, type(uint256).max);

    token.mint(_from, _balance);

    vm.prank(_from);
    assertTrue(token.approve(_from, _allowance));

    vm.prank(_from);
    assertTrue(token.transferFrom(_from, _from, _amount));

    assertEq(token.balanceOf(_from), _balance);
    assertEq(token.allowance(_from, _from), _allowance != type(uint256).max ? _allowance - _amount : _allowance);
  }

  function test_transferFrom(address _spender, address _from, address _to, uint256 _balance, uint256 _allowance, uint256 _amount) external {
    _from = boundDiff(_from, _to);

    _amount = bound(_amount, 0, _balance);
    _allowance = bound(_allowance, _amount, type(uint256).max);

    token.mint(_from, _balance);

    vm.prank(_from);
    assertTrue(token.approve(_spender, _allowance));

    vm.prank(_spender);
    assertTrue(token.transferFrom(_from, _to, _amount));

    assertEq(token.balanceOf(_from), _balance - _amount);
    assertEq(token.balanceOf(_to), _amount);

    assertEq(token.allowance(_from, _spender), _allowance != type(uint256).max ? _allowance - _amount : _allowance);
  }

  function test_fail_transferFromNotEnoughBalance(address _spender, address _from, address _to, uint256 _balance, uint256 _allowance, uint256 _amount) external {
    _balance = boundDiff(_balance, type(uint256).max);

    _amount = bound(_amount, _balance + 1, type(uint256).max);
    _allowance = bound(_allowance, _amount, type(uint256).max);

    token.mint(_from, _balance);

    vm.prank(_from);
    assertTrue(token.approve(_spender, _allowance));

    vm.prank(_spender);
    vm.expectRevert(abi.encodeWithSignature("NotEnoughBalance(address,uint256,uint256)", _from, _balance, _amount));
    token.transferFrom(_from, _to, _amount);
  }

  function test_fail_transferFromNotEnoughAllowance(address _spender, address _from, address _to, uint256 _balance, uint256 _allowance, uint256 _amount) external {
    _balance = boundDiff(_balance, 0);

    _amount = bound(_amount, 1, _balance);
    _allowance = bound(_allowance, 0, _amount - 1);

    token.mint(_from, _balance);

    vm.prank(_from);
    assertTrue(token.approve(_spender, _allowance));

    vm.prank(_spender);
    vm.expectRevert(abi.encodeWithSignature("NotEnoughAllowance(address,address,uint256,uint256)", _from, _spender, _allowance, _amount));
    token.transferFrom(_from, _to, _amount);
  }

  function test_transferFromSpenderIsFrom(address _from, address _to, uint256 _balance, uint256 _allowance, uint256 _amount) external {
    _from = boundDiff(_from, _to);

    _amount = bound(_amount, 0, _balance);
    _allowance = bound(_allowance, _amount, type(uint256).max);

    token.mint(_from, _balance);

    vm.prank(_from);
    assertTrue(token.approve(_from, _allowance));

    vm.prank(_from);
    assertTrue(token.transferFrom(_from, _to, _amount));

    assertEq(token.balanceOf(_from), _balance - _amount);
    assertEq(token.balanceOf(_to), _amount);

    assertEq(token.allowance(_from, _from), _allowance != type(uint256).max ? _allowance - _amount : _allowance);
  }

  function test_transferFromSpenderIsTo(address _from, address _to, uint256 _balance, uint256 _allowance, uint256 _amount) external {
    _from = boundDiff(_from, _to);

    _amount = bound(_amount, 0, _balance);
    _allowance = bound(_allowance, _amount, type(uint256).max);

    token.mint(_from, _balance);

    vm.prank(_from);
    assertTrue(token.approve(_to, _allowance));

    vm.prank(_to);
    assertTrue(token.transferFrom(_from, _to, _amount));

    assertEq(token.balanceOf(_from), _balance - _amount);
    assertEq(token.balanceOf(_to), _amount);

    assertEq(token.allowance(_from, _to), _allowance != type(uint256).max ? _allowance - _amount : _allowance);
  }

  function test_setMetadata(string memory _name, string memory _symbol, uint8 _decimals) external {
    token = new ImpToken(_name, _symbol, _decimals);
    assertEq(token.name(), _name);
    assertEq(token.symbol(), _symbol);
    assertEq(token.decimals(), _decimals);
  }

  function test_transferOverflow(address _from, address _to, uint256 _balance, uint256 _amount) external {
    _from = boundDiff(_from, _to);

    _balance = bound(_balance, 1, type(uint256).max);
    _amount = bound(_amount, type(uint256).max - _balance + 1, type(uint256).max);

    token.mintWithoutIncreasingSupply(_to, _balance);
    token.mintWithoutIncreasingSupply(_from, _amount);

    vm.prank(_from);
    vm.expectRevert(stdError.arithmeticError);
    token.transfer(_to, _amount);
  }

  function test_mintOverflow(address _to, uint256 _balance, uint256 _amount) external {
    _balance = bound(_balance, 1, type(uint256).max);
    _amount = bound(_amount, type(uint256).max - _balance + 1, type(uint256).max);

    token.mint(_to, _balance);
    vm.prank(_to);
    vm.expectRevert(stdError.arithmeticError);
    token.mint(_to, _amount);
  }

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  function test_mintEvent(address _to, uint256 _amount) external {
    vm.expectEmit(true, true, true, true, address(token));
    emit Transfer(address(0), _to, _amount);
    token.mint(_to, _amount);
  }

  function test_transferEvent(address _from, address _to, uint256 _balance, uint256 _amount) external {
    _to = boundDiff(_to, address(token));

    _amount = bound(_amount, 0, _balance);

    token.mint(_from, _balance);

    vm.expectEmit(true, true, true, true, address(token));
    emit Transfer(_from, _to, _amount);
    vm.prank(_from);
    token.transfer(_to, _amount);
  }

  function test_transferEventOnTransferFrom(
    address _spender,
    address _from,
    address _to,
    uint256 _balance,
    uint256 _allowance,
    uint256 _amount
  ) external {
    _amount = bound(_amount, 0, _balance);
    _allowance = bound(_allowance, _amount, type(uint256).max);

    token.mint(_from, _balance);

    vm.prank(_from);
    token.approve(_spender, _allowance);

    vm.prank(_spender);
    vm.expectEmit(true, true, true, true, address(token));
    emit Transfer(_from, _to, _amount);
    token.transferFrom(_from, _to, _amount);
  }

  function test_approveEvent(address _spender, address _from, uint256 _amount) external {
    vm.prank(_spender);
    vm.expectEmit(true, true, true, true, address(token));
    emit Approval(_spender, _from, _amount);
    token.approve(_from, _amount);
  }
}
