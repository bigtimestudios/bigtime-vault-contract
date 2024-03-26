// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/workers/ECDSAWorker.sol";

import "test/utils/ECDSA.t.sol";


contract ECDSAWorkerTest is AdvTest {
  event Relayed1(uint256 indexed _index, address _to);
  event Relayed2(uint256 indexed _index, address _to);

  function _signAndEncode(
    uint256 _pk,
    bytes32 _hash
  ) internal returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, _hash);
    return abi.encodePacked(r, s, v);
  }

  function test_sendTx(
    uint256 _pk,
    address _caller,
    address _to,
    uint256 _index,
    bytes calldata _payload
  ) external {
    vm.startPrank(_caller);

    _pk = boundPk(_pk);

    ECDSAWorker worker = new ECDSAWorker(vm.addr(_pk));

    _to = boundNoSys(_to);
    _to = boundDiff(boundDiff(_to, address(this)), address(worker));

    bytes32 txHash = worker.hashTx(_to, _index, _payload);

    bytes memory signature = _signAndEncode(_pk, txHash);

    assertFalse(worker.isUsed(_index));

    vm.expectCall(_to, _payload);

    vm.expectEmit(true, true, true, true, address(worker));
    emit Relayed1(_index, _to);

    worker.sendTx(_to, _index, _payload, signature);

    assertTrue(worker.isUsed(_index));

    // replay should fail
    vm.expectRevert(abi.encodeWithSignature("IndexUsed(uint256)", _index));
    worker.sendTx(_to, _index, _payload, signature);
  }

  function test_sendTx2(
    uint256 _pk,
    address _caller,
    address _to,
    uint256 _index,
    bytes calldata _payload1,
    bytes calldata _payload2
  ) external {
    vm.startPrank(_caller);

    _pk = boundPk(_pk);

    ECDSAWorker worker = new ECDSAWorker(vm.addr(_pk));

    _to = boundNoSys(_to);
    _to = boundDiff(boundDiff(_to, address(this)), address(worker));

    bytes32 txHash = worker.hashTx2(_to, _index, _payload1, _payload2);
    bytes memory signature = _signAndEncode(_pk, txHash);

    assertFalse(worker.isUsed(_index));

    vm.expectCall(_to, _payload1);
    vm.expectCall(_to, _payload2);

    vm.expectEmit(true, true, true, true, address(worker));
    emit Relayed2(_index, _to);

    worker.sendTx2(_to, _index, _payload1, _payload2, signature);

    assertTrue(worker.isUsed(_index));

    // replay should fail
    vm.expectRevert(abi.encodeWithSignature("IndexUsed(uint256)", _index));
    worker.sendTx2(_to, _index, _payload1, _payload2, signature);
  }

  function test_sendTx_Twice(
    uint256 _pk,
    address _caller,
    address _to1,
    uint256 _index1,
    bytes calldata _payload1,
    address _to2,
    uint256 _index2,
    bytes calldata _payload2
  ) external {
    vm.startPrank(_caller);

    _pk = boundPk(_pk);
    _index1 = boundDiff(_index1, _index2);

    ECDSAWorker worker = new ECDSAWorker(vm.addr(_pk));

    _to1 = boundNoSys(_to1);
    _to1 = boundDiff(boundDiff(_to1, address(this)), address(worker));

    _to2 = boundNoSys(_to2);
    _to2 = boundDiff(boundDiff(_to2, address(this)), address(worker));

    bytes32 txHash = worker.hashTx(_to1, _index1, _payload1);
    bytes memory signature = _signAndEncode(_pk, txHash);

    worker.sendTx(_to1, _index1, _payload1, signature);

    txHash = worker.hashTx(_to2, _index2, _payload2);
    signature = _signAndEncode(_pk, txHash);

    vm.expectCall(_to2, _payload2);

    vm.expectEmit(true, true, true, true, address(worker));
    emit Relayed1(_index2, _to2);

    worker.sendTx(_to2, _index2, _payload2, signature);

    assertTrue(worker.isUsed(_index1));
    assertTrue(worker.isUsed(_index2));

    vm.expectRevert(abi.encodeWithSignature("IndexUsed(uint256)", _index1));
    worker.sendTx(_to1, _index1, _payload1, signature);

    vm.expectRevert(abi.encodeWithSignature("IndexUsed(uint256)", _index2));
    worker.sendTx(_to1, _index2, _payload2, signature);
  }

  function test_fail_sendTx_Imposter(
    address _signer,
    uint256 _pkImposter,
    address _caller,
    address _to,
    uint256 _index,
    bytes calldata _payload
  ) external {
    _signer = boundDiff(_signer, address(0));

    vm.startPrank(_caller);

    _pkImposter = boundPk(_pkImposter);

    address imposterAddr = vm.addr(_pkImposter);
    _signer = boundDiff(_signer, imposterAddr);

    ECDSAWorker worker = new ECDSAWorker(_signer);

    bytes32 txHash = worker.hashTx(_to, _index, _payload);
    bytes memory signature = _signAndEncode(_pkImposter, txHash);

    vm.expectRevert(abi.encodeWithSignature("InvalidSignature(bytes32,address,bytes)", txHash, imposterAddr, signature));
    worker.sendTx(_to, _index, _payload, signature);

    assertFalse(worker.isUsed(_index));
  }

  function test_fail_sendTx2_Imposter(
    address _signer,
    uint256 _pkImposter,
    address _caller,
    address _to,
    uint256 _index,
    bytes calldata _payload1,
    bytes calldata _payload2
  ) external {
    _signer = boundDiff(_signer, address(0));

    vm.startPrank(_caller);

    _pkImposter = boundPk(_pkImposter);

    address imposterAddr = vm.addr(_pkImposter);
    _signer = boundDiff(_signer, imposterAddr);

    ECDSAWorker worker = new ECDSAWorker(_signer);

    bytes32 txHash = worker.hashTx2(_to, _index, _payload1, _payload2);
    bytes memory signature = _signAndEncode(_pkImposter, txHash);

    vm.expectRevert(abi.encodeWithSignature("InvalidSignature(bytes32,address,bytes)", txHash, imposterAddr, signature));
    worker.sendTx2(_to, _index, _payload1, _payload2, signature);

    assertFalse(worker.isUsed(_index));
  }

  function test_fail_sendTx_RandomSignature(
    address _signer,
    address _caller,
    address _to,
    uint256 _index,
    bytes calldata _payload,
    bytes calldata _badsignature
  ) external {
    _signer = boundDiff(_signer, address(0));

    vm.startPrank(_caller);

    ECDSAWorker worker = new ECDSAWorker(_signer);
    bytes32 txHash = worker.hashTx(_to, _index, _payload);
    address badSigner = ECDSA.recover(txHash, _badsignature);

    _signer = boundDiff(_signer, badSigner);
    
    vm.expectRevert(abi.encodeWithSignature("InvalidSignature(bytes32,address,bytes)", txHash, badSigner, _badsignature));
    worker.sendTx(_to, _index, _payload, _badsignature);

    assertFalse(worker.isUsed(_index));
  }

  function test_fail_sendTx_RandomSignature2(
    address _signer,
    address _caller,
    address _to,
    uint256 _index,
    bytes calldata _payload,
    bytes32 _r,
    bytes32 _s,
    uint8 _v
  ) external {
    _signer = boundDiff(_signer, address(0));

    vm.startPrank(_caller);

    bytes memory badsignature = abi.encodePacked(_r, _s, _v);

    ECDSAWorker worker = new ECDSAWorker(_signer);
    bytes32 txHash = worker.hashTx(_to, _index, _payload);
    address badSigner = new ECDSAImp().recover(txHash, badsignature, bytes(''));

    _signer = boundDiff(_signer, badSigner);
    
    vm.expectRevert(abi.encodeWithSignature("InvalidSignature(bytes32,address,bytes)", txHash, badSigner, badsignature));
    worker.sendTx(_to, _index, _payload, badsignature);

    assertFalse(worker.isUsed(_index));
  }

  function test_fail_sendTx2_RandomSignature(
    address _signer,
    address _caller,
    address _to,
    uint256 _index,
    bytes calldata _payload1,
    bytes calldata _payload2,
    bytes32 _r,
    bytes32 _s,
    uint8 _v
  ) external {
    _signer = boundDiff(_signer, address(0));

    vm.startPrank(_caller);

    bytes memory badsignature = abi.encodePacked(_r, _s, _v);

    ECDSAWorker worker = new ECDSAWorker(_signer);
    bytes32 txHash = worker.hashTx2(_to, _index, _payload1, _payload2);
    address badSigner = new ECDSAImp().recover(txHash, badsignature, bytes(''));

    vm.expectRevert(abi.encodeWithSignature("InvalidSignature(bytes32,address,bytes)", txHash, badSigner, badsignature));
    worker.sendTx2(_to, _index, _payload1, _payload2, badsignature);

    assertFalse(worker.isUsed(_index));
  }

  function test_fail_sendTx2_RandomSignature2(
    address _signer,
    address _caller,
    address _to,
    uint256 _index,
    bytes calldata _payload1,
    bytes calldata _payload2,
    bytes calldata _badsignature
  ) external {
    _signer = boundDiff(_signer, address(0));

    vm.startPrank(_caller);

    ECDSAWorker worker = new ECDSAWorker(_signer);
    bytes32 txHash = worker.hashTx2(_to, _index, _payload1, _payload2);
    address badSigner = ECDSA.recover(txHash, _badsignature);

    _signer = boundDiff(_signer, badSigner);
    
    vm.expectRevert(abi.encodeWithSignature("InvalidSignature(bytes32,address,bytes)", txHash, badSigner, _badsignature));
    worker.sendTx2(_to, _index, _payload1, _payload2, _badsignature);

    assertFalse(worker.isUsed(_index));
  }

  function test_hashTx_Distinct(
    address _toa,
    uint256 _indexa,
    bytes calldata _payloada,
    address _tob,
    uint256 _indexb,
    bytes calldata _payloadb
  ) external {
    ECDSAWorker worker = new ECDSAWorker(address(this));

    bytes32 txHasha = worker.hashTx(_toa, _indexa, _payloada);
    bytes32 txHashb = worker.hashTx(_tob, _indexb, _payloadb);

    if (_toa == _tob && _indexa == _indexb && keccak256(_payloada) == keccak256(_payloadb)) {
      assertTrue(txHasha == txHashb);
    } else {
      assertTrue(txHasha != txHashb);
    }
  }

  function test_hashTx2_Distinct(
    address _toa,
    uint256 _indexa,
    bytes calldata _payload1a,
    bytes calldata _payload2a,
    address _tob,
    uint256 _indexb,
    bytes calldata _payload1b,
    bytes calldata _payload2b
  ) external {
    ECDSAWorker worker = new ECDSAWorker(address(this));

    bytes32 txHasha = worker.hashTx2(_toa, _indexa, _payload1a, _payload2a);
    bytes32 txHashb = worker.hashTx2(_tob, _indexb, _payload1b, _payload2b);

    if (
      _toa == _tob &&
      _indexa == _indexb &&
      keccak256(_payload1a) == keccak256(_payload1b) &&
      keccak256(_payload2a) == keccak256(_payload2b)
    ) {
      assertTrue(txHasha == txHashb);
    } else {
      assertTrue(txHasha != txHashb);
    }
  }

  function test_hashTx1_Distinct_Worker(
    address _to,
    uint256 _index,
    bytes calldata _payload
  ) external {
    ECDSAWorker worker1 = new ECDSAWorker(address(this));
    ECDSAWorker worker2 = new ECDSAWorker(address(this));

    bytes32 txHasha = worker1.hashTx(_to, _index, _payload);
    bytes32 txHashb = worker2.hashTx(_to, _index, _payload);

    assertTrue(txHasha != txHashb);
  }

  function test_hashTx1_Distinct_Worker_Fuzz(
    address _toa,
    uint256 _indexa,
    bytes calldata _payloada,
    address _tob,
    uint256 _indexb,
    bytes calldata _payloadb
  ) external {
    ECDSAWorker worker1 = new ECDSAWorker(address(this));
    ECDSAWorker worker2 = new ECDSAWorker(address(this));

    bytes32 txHasha = worker1.hashTx(_toa, _indexa, _payloada);
    bytes32 txHashb = worker2.hashTx(_tob, _indexb, _payloadb);

    assertTrue(txHasha != txHashb);
  }

  function test_hashTx2_Distinct_Worker(
    address _to,
    uint256 _index,
    bytes calldata _payload1,
    bytes calldata _payload2
  ) external {
    ECDSAWorker worker1 = new ECDSAWorker(address(this));
    ECDSAWorker worker2 = new ECDSAWorker(address(this));

    bytes32 txHasha = worker1.hashTx2(_to, _index, _payload1, _payload2);
    bytes32 txHashb = worker2.hashTx2(_to, _index, _payload1, _payload2);

    assertTrue(txHasha != txHashb);
  }

  function test_hashTx2_Distinct_Worker_Fuzz(
    address _toa,
    uint256 _indexa,
    bytes calldata _payloada1,
    bytes calldata _payloada2,
    address _tob,
    uint256 _indexb,
    bytes calldata _payloadb1,
    bytes calldata _payloadb2
  ) external {
    bytes32 txHasha = new ECDSAWorker(address(this)).hashTx2(_toa, _indexa, _payloada1, _payloada2);
    bytes32 txHashb = new ECDSAWorker(address(this)).hashTx2(_tob, _indexb, _payloadb1, _payloadb2);

    assertTrue(txHasha != txHashb);
  }

  function test_hashTx1_Distinct_ChainId(
    address _to,
    uint256 _index,
    bytes calldata _payload,
    uint256 _chainId1,
    uint256 _chainId2
  ) external {
    _chainId1 = boundChainId(_chainId1);
    _chainId2 = boundChainId(_chainId2);

    ECDSAWorker worker = new ECDSAWorker(address(this));

    vm.chainId(_chainId1);
    bytes32 txHasha = worker.hashTx(_to, _index, _payload);

    vm.chainId(_chainId2);
    bytes32 txHashb = worker.hashTx(_to, _index, _payload);

    assertTrue(txHasha != txHashb || _chainId1 == _chainId2);
  }

  function test_hashTx2_Distinct_ChainId(
    address _to,
    uint256 _index,
    bytes calldata _payload1,
    bytes calldata _payload2,
    uint256 _chainId1,
    uint256 _chainId2
  ) external {
    _chainId1 = boundChainId(_chainId1);
    _chainId2 = boundChainId(_chainId2);

    ECDSAWorker worker = new ECDSAWorker(address(this));

    vm.chainId(_chainId1);
    bytes32 txHasha = worker.hashTx2(_to, _index, _payload1, _payload2);

    vm.chainId(_chainId2);
    bytes32 txHashb = worker.hashTx2(_to, _index, _payload1, _payload2);

    assertTrue(txHasha != txHashb || _chainId1 == _chainId2);
  }
}
