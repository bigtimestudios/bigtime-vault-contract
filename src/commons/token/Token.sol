// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/interfaces/IERC20.sol";


contract Token is IERC20 {
  error NotEnoughBalance(address _sender, uint256 _balance, uint256 _amount);
  error NotEnoughAllowance(address _sender, address _spender, uint256 _allowance, uint256 _amount);

  string public name;
  string public symbol;
  uint8 public immutable decimals;

  uint256 public totalSupply;

  mapping(address => uint256) private balances;
  mapping(address => mapping(address => uint256)) private allowances;

  constructor(string memory _name, string memory _symbol, uint8 _decimals) {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
  }

  function balanceOf(address _account) external view returns (uint256) {
    return balances[_account];
  }

  function allowance(address _owner, address _spender) external view returns (uint256) {
    return allowances[_owner][_spender];
  }

  function approve(address _spender, uint256 _amount) external returns (bool) {
    _approve(msg.sender, _spender, _amount);
    return true;
  }

  function transfer(address _to, uint256 _amount) external returns (bool) {
    _transfer(msg.sender, _to, _amount);
    return true;
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _amount
  ) external returns (bool) {
    uint256 prevAllowance = allowances[_from][msg.sender];
    if (prevAllowance != type(uint256).max) {
      if (prevAllowance < _amount) {
        revert NotEnoughAllowance(_from, msg.sender, prevAllowance, _amount);
      }

      allowances[_from][msg.sender] = prevAllowance - _amount;
    }

    _transfer(_from, _to, _amount);
    return true;
  }

  function _approve(
    address _owner,
    address _spender,
    uint256 _amount
  ) internal {
    allowances[_owner][_spender] = _amount;
    emit Approval(_owner, _spender, _amount);
  }

  function _transfer(
    address _from,
    address _to,
    uint256 _amount
  ) internal virtual {
    uint256 prevBalance = balances[_from];
    if (prevBalance < _amount) {
      revert NotEnoughBalance(_from, prevBalance, _amount);
    }

    balances[_from] = prevBalance - _amount;
    balances[_to] += _amount;

    emit Transfer(_from, _to, _amount);
  }

  function _mint(address _to, uint256 _amount) internal virtual {
    balances[_to] += _amount;
    totalSupply += _amount;
    emit Transfer(address(0), _to, _amount);
  }
}
