// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/workers/ECDSAWorker.sol";
import "src/Vault.sol";
import "src/commons/token/MintableToken.sol";

import "test/forge/AdvTest.sol";


contract VaultTest is AdvTest {
  Vault vault;

  function setUp() external {
    vault = new Vault();
  }

  function _signAndEncode(
    uint256 _pk,
    bytes32 _hash
  ) internal returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, _hash);
    return abi.encodePacked(r, s, v);
  }

  function _addWorker(
    uint256 _pk
  ) internal returns (ECDSAWorker) {
    ECDSAWorker worker = new ECDSAWorker(vm.addr(_pk));
    uint8[] memory permissions = new uint8[](5);
    permissions[0] = 1;
    permissions[1] = 2;
    permissions[2] = 3;
    permissions[3] = 4;
    permissions[4] = 5;
    vault.addPermissions(address(worker), permissions);
    return worker;
  }

  function test_sweepAndSendTokens(
    uint256 _id1,
    uint256 _id2,
    uint256 _amount1,
    uint256 _amount2,
    uint256 _send,
    address _to,
    uint256 _workerpk,
    uint256 _index
  ) external {
    MintableToken token = new MintableToken("", "", 0);

    _workerpk = boundPk(_workerpk);
    _to = boundDiff(_to, address(token));
    _amount2 = bound(_amount2, 0, type(uint256).max - _amount1);
    _send = bound(_send, 0, _amount1 + _amount2);
  
    _to = boundDiff(_to, address(vault.receiverFor(_id1)));
    _to = boundDiff(_to, address(vault.receiverFor(_id2)));

    token.mint(address(vault.receiverFor(_id1)), _amount1);
    token.mint(address(vault.receiverFor(_id2)), _amount2);

    ECDSAWorker worker = _addWorker(_workerpk);

    {
    uint256[] memory ids = new uint256[](2);
    ids[0] = _id1;
    ids[1] = _id2;

    bytes memory sweepData = abi.encodeWithSelector(
      vault.sweepBatchERC20.selector,
      token,
      ids
    );

    bytes memory sendData = abi.encodeWithSelector(
      vault.sendERC20.selector,
      token,
      _to,
      _send
    );

    bytes32 messageHash = worker.hashTx2(
      address(vault),
      _index,
      sweepData,
      sendData
    );

    bytes memory signature = _signAndEncode(_workerpk, messageHash);
    worker.sendTx2(
      address(vault),
      _index,
      sweepData,
      sendData,
      signature
    );

    // Replay should fail
    vm.expectRevert(abi.encodeWithSignature("IndexUsed(uint256)", _index));
    worker.sendTx2(
      address(vault),
      _index,
      sweepData,
      sendData,
      signature
    );
    }

    assertTrue(worker.isUsed(_index));
    assertEq(token.balanceOf(address(vault.receiverFor(_id1))), 0, "r1b");
    assertEq(token.balanceOf(address(vault.receiverFor(_id2))), 0, "r2b");

    if (_to == address(vault)) {
      assertEq(token.balanceOf(_to), _amount1 + _amount2, "tb");
    } else {
      assertEq(token.balanceOf(_to), _send, "tb");
    }
  }
}
