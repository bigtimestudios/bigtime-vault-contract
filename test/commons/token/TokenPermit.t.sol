// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/token/TokenPermit.sol";

import "test/forge/AdvTest.sol";


contract TokenPermitImp is TokenPermit {
  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals
  ) TokenPermit(_name, _symbol, _decimals) {}

  function mint(address _to, uint256 _val) external {
    _mint(_to, _val);
  }

  function setNonce(address _owner, uint256 _nonce) external {
    nonces[_owner] = _nonce;
  }
}

contract TokenPermitTest is AdvTest {
  TokenPermitImp token;

  function setUp() external {
    token = new TokenPermitImp("Token", "TKN", 18);
  }

  function test_DOMAIN_SEPARATOR_Name(string calldata _name1, string calldata _name2) external {
    TokenPermitImp token1 = new TokenPermitImp(_name1, "TKN", 18);
    TokenPermitImp token2 = new TokenPermitImp(_name2, "TKN", 18);

    assertTrue(
      token1.DOMAIN_SEPARATOR() != token2.DOMAIN_SEPARATOR() ||
      keccak256(bytes(_name1)) == keccak256(bytes(_name2))
    );
  }

  function test_DOMAIN_SEPARATOR_Address(address _token1, address _token2) external {
    _token1 = boundNoSys(_token1);
    _token2 = boundNoSys(_token1);

    vm.etch(_token1, address(token).code);
    vm.etch(_token2, address(token).code);

    // change chainid, forces recompute of domain separator
    vm.chainId(block.chainid + 1);

    assertTrue(
      TokenPermit(_token1).DOMAIN_SEPARATOR() != TokenPermit(_token2).DOMAIN_SEPARATOR() ||
      _token1 == _token2
    );
  }

  function test_DOMAIN_SEPARATOR_ChainId(string calldata _name, uint256 _chainId1, uint256 _chainId2) external {
    _chainId1 = boundChainId(_chainId1);
    _chainId2 = boundChainId(_chainId2);

    vm.chainId(_chainId1);
    TokenPermitImp token1 = new TokenPermitImp(_name, "TKN", 18);
    bytes32 domainSeparator1 = token1.DOMAIN_SEPARATOR();

    vm.chainId(_chainId2);
    TokenPermitImp token2 = new TokenPermitImp(_name, "TKN", 18);
    bytes32 domainSeparator2 = token2.DOMAIN_SEPARATOR();

    assertTrue(
      domainSeparator1 != domainSeparator2 ||
      _chainId1 == _chainId2
    );
  }

  function test_DOMAIN_SEPARATOR_ChainId_Changed(string calldata _name, uint256 _cid1, uint256 _cid2, uint256 _ncid1, uint256 _ncid2) external {
    _cid1 = boundChainId(_cid1);
    _cid2 = boundChainId(_cid2);
    _ncid1 = boundChainId(_ncid1);
    _ncid2 = boundChainId(_ncid2);

    vm.chainId(_cid1);
    TokenPermitImp token1 = new TokenPermitImp(_name, "TKN", 18);

    vm.chainId(_cid2);
    TokenPermitImp token2 = new TokenPermitImp(_name, "TKN", 18);

    vm.chainId(_ncid1);
    bytes32 domainSeparator1 = token1.DOMAIN_SEPARATOR();

    vm.chainId(_ncid2);
    bytes32 domainSeparator2 = token2.DOMAIN_SEPARATOR();

    assertTrue(
      domainSeparator1 != domainSeparator2 ||
      _ncid1 == _ncid2
    );
  }

  event Approval(address indexed owner, address indexed spender, uint256 value);

  function test_permit(
    address _sender,
    uint256 _pk,
    uint256 _prevAlloance,
    uint256 _prevNonce,
    address _spender,
    uint256 _value,
    uint256 _deadline,
    uint256 _sendsVal,
    address _sendsTo
  ) external {
    _pk = boundPk(_pk);
    _sendsVal = bound(_sendsVal, 0, _value);
    _sendsTo = boundDiff(_sendsTo, address(token));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _prevNonce = bound(_prevNonce, 0, type(uint256).max - 1);

    address owner = vm.addr(_pk);

    vm.prank(owner);
    token.approve(_spender, _prevAlloance);
    token.setNonce(owner, _prevNonce);

    bytes32 digest = keccak256(
      abi.encodePacked(
        hex"1901",
        token.DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner,
            _spender,
            _value,
            _prevNonce,
            _deadline
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, digest);

    vm.prank(_sender);
    vm.expectEmit(true, true, true, true, address(token));
    emit Approval(owner, _spender, _value);
    token.permit(owner, _spender, _value, _deadline, v, r, s);

    assertEq(token.nonces(owner), _prevNonce + 1);
    assertEq(token.allowance(owner, _spender), _value);

    token.mint(owner, _value);

    vm.prank(_spender);
    token.transferFrom(owner, _sendsTo, _sendsVal);

    if (_sendsTo == owner) {
      assertEq(token.balanceOf(owner), _value);
    } else {
      assertEq(token.balanceOf(owner), _value - _sendsVal);
      assertEq(token.balanceOf(_sendsTo), _sendsVal);
    }
  }

  function test_fail_permit_Expired(
    address _sender,
    address _owner,
    address _spender,
    uint256 _value,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external {
    _deadline = bound(_deadline, 0, block.timestamp - 1);

    vm.expectRevert(abi.encodeWithSignature('ExpiredPermit(address,address,uint256,uint256)', _owner, _spender, _value, _deadline));
    vm.prank(_sender);
    token.permit(_owner, _spender, _value, _deadline, _v, _r, _s);
  }

  function test_fail_permit_OwnerZero(
    address _sender,
    address _spender,
    uint256 _value,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external {
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    vm.expectRevert(abi.encodeWithSignature('InvalidPermitOwner(address)', address(0)));
    vm.prank(_sender);
    token.permit(address(0), _spender, _value, _deadline, _v, _r, _s);
  }

  function test_fail_permit_BadSignature(
    address _sender,
    address _owner,
    uint256 _badPk,
    uint256 _prevNonce,
    address _spender,
    uint256 _value,
    uint256 _deadline
  ) external {
    _badPk = boundPk(_badPk);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _owner = boundDiff(_owner, vm.addr(_badPk), address(0));

    token.setNonce(_owner, _prevNonce);

    bytes32 digest = keccak256(
      abi.encodePacked(
        hex"1901",
        token.DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            _owner,
            _spender,
            _value,
            _prevNonce,
            _deadline
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_badPk, digest);

    vm.expectRevert(
      abi.encodeWithSignature(
        'InvalidPermitSignature(address,address,uint256,uint256,uint256,uint8,bytes32,bytes32)',
        _owner, _spender, _value, _prevNonce, _deadline, v, r, s
      )
    );

    vm.prank(_sender);
    token.permit(_owner, _spender, _value, _deadline, v, r, s);
  }

  function test_fail_permit_ChainIdChange(
    address _sender,
    uint256 _pk,
    uint256 _prevNonce,
    address _spender,
    uint256 _value,
    uint256 _deadline,
    uint64 _newChainId
  ) external {
    _pk = boundPk(_pk);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _newChainId = uint64(boundChainId(boundDiff(_newChainId, block.chainid)));

    address owner = vm.addr(_pk);

    token.setNonce(owner, _prevNonce);

    bytes32 digest = keccak256(
      abi.encodePacked(
        hex"1901",
        token.DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner,
            _spender,
            _value,
            _prevNonce,
            _deadline
          )
        )
      )
    );

    vm.chainId(_newChainId);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, digest);

    vm.expectRevert(
      abi.encodeWithSignature(
        'InvalidPermitSignature(address,address,uint256,uint256,uint256,uint8,bytes32,bytes32)',
        owner, _spender, _value, _prevNonce, _deadline, v, r, s
      )
    );

    vm.prank(_sender);
    token.permit(owner, _spender, _value, _deadline, v, r, s);
  }
}
