// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/utils/ECDSA.sol";


contract ECDSAWorker {
  address immutable public signer;

  mapping(uint256 => uint256) private usedBitmap;

  error IndexUsed(uint256 _index);
  error InvalidSignature(bytes32 _hash, address _recovered, bytes _signature);
  error TransactionFailed(uint256 _index, uint256 _i, address _to, bytes _payload, bytes _result);
  error InvalidSigner();

  event Relayed1(uint256 indexed _index, address _to);
  event Relayed2(uint256 indexed _index, address _to);

  bytes32 public constant TX_1_TYPEHASH = keccak256("Tx(address worker,uint256 chainid,address to,uint256 index,bytes payload)");
  bytes32 public constant TX_2_TYPEHASH = keccak256("Tx(address worker,uint256 chainid,address to,uint256 index,bytes payload1,bytes payload2)");

  constructor (address _signer) {
    if (_signer == address(0)) revert InvalidSigner();
    signer = _signer;
  }

  function isUsed(uint256 _index) external view returns (bool) {
    unchecked {
      uint256 usedWordIndex = _index / 256;
      uint256 usedBitIndex = _index % 256;
      uint256 usedWord = usedBitmap[usedWordIndex];
      uint256 mask = (1 << usedBitIndex);
      return usedWord & mask == mask; 
    }
  }

  function _consume(uint256 _index) internal {
    unchecked {
      uint256 usedWordIndex = _index / 256;
      uint256 usedBitIndex = _index % 256;
      uint256 usedWord = usedBitmap[usedWordIndex];
      uint256 mask = (1 << usedBitIndex);
      if (usedWord & mask == mask) revert IndexUsed(_index);
      usedBitmap[usedWordIndex] = usedWord | mask;
    }
  }

  function _validate(bytes32 _hash, uint256 _index, bytes calldata _signature) internal {
    _consume(_index);

    address recovered = ECDSA.recover(_hash, _signature);
    if (recovered != signer) {
      revert InvalidSignature(_hash, recovered, _signature);
    }
  }

  function hashTx(
    address _to,
    uint256 _index,
    bytes memory _payload
  ) public view returns (bytes32) {
    return keccak256(
      abi.encode(
        TX_1_TYPEHASH,
        address(this),
        block.chainid,
        _to,
        _index,
        keccak256(_payload)
      )
    );
  }

  function sendTx(
    address _to,
    uint256 _index,
    bytes memory _payload,
    bytes calldata _signature
  ) external {
    bytes32 txHash = hashTx(_to, _index, _payload);
    _validate(txHash, _index, _signature);

    (bool success, bytes memory result) = _to.call(_payload);
    if (!success) revert TransactionFailed(_index, 0, _to, _payload, result);

    emit Relayed1(_index, _to);
  }

  function hashTx2(
    address _to,
    uint256 _index,
    bytes memory _payload1,
    bytes memory _payload2
  ) public view returns (bytes32) {
    return keccak256(
      abi.encode(
        TX_2_TYPEHASH,
        address(this),
        block.chainid,
        _to,
        _index,
        keccak256(_payload1),
        keccak256(_payload2)
      )
    );
  }

  function sendTx2(
    address _to,
    uint256 _index,
    bytes memory _payload1,
    bytes memory _payload2,
    bytes calldata _signature
  ) external {
    bytes32 txHash = hashTx2(_to, _index, _payload1, _payload2);
    _validate(txHash, _index, _signature);

    (bool success, bytes memory result) = _to.call(_payload1);
    if (!success) revert TransactionFailed(_index, 0, _to, _payload1, result);

    (success, result) = _to.call(_payload2);
    if (!success) revert TransactionFailed(_index, 1, _to, _payload2, result);

    emit Relayed2(_index, _to);
  }
}
