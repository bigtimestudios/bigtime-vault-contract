// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/receiver/Receiver.sol";

import "test/forge/AdvTest.sol";


contract ReceiverTest is AdvTest {
  Receiver receiver;

  function setUp() external {
    receiver = new Receiver();
  }

  function _boundAddr(address _addr) internal view returns (address res) {
    res = boundNoSys(_addr);
    res = boundDiff(res, address(this));
  }

  function test_execute(address payable _to, bytes calldata _data) external {
    _to = payable(_boundAddr(_to));

    vm.expectCall(_to, _data);
    (bool res,) = receiver.execute(_to, 0, _data);
    assertTrue(res);
  }

  function test_rejectNonOwner(address _from, address payable _to, uint256 _val, bytes calldata _data) external {
    vm.assume(_from != address(this));
    vm.prank(_from);
    vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address)", _from));
    receiver.execute(_to, _val, _data);
  }

  function test_receiveAndSendETH(address payable _to, uint256 _bal, uint256 _val, bytes memory _data) public {
    _to = payable(_boundAddr(_to));
    _val = bound(_val, 0, _bal);

    vm.deal(_to, 0);
    vm.deal(address(this), _bal);
    payable(receiver).transfer(_bal);

    vm.expectCall(_to, _data);
    (bool res,) = receiver.execute(_to, _val, _data);

    if (_to == address(this)) {
      assertFalse(res);
      assertEq(address(receiver).balance, _bal);
      assertEq(address(_to).balance, 0);
    } else if (_to != address(receiver)) {
      assertTrue(res);
      assertEq(address(receiver).balance, _bal - _val);
      assertEq(address(_to).balance, _val);
    } else {
      assertTrue(res);
      assertEq(address(receiver).balance, _bal);
    }
  }

  function test_receiveAndSendETH_replicate_1() external {
    address payable _to = payable(address(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84));
    uint256 _bal = 115792089237316195423570985007226406215939081747436879206741300988257197096960;
    uint256 _val = 1032069922050249630382865877677304880282300743300;
    bytes memory _data = hex'ffffffffffffffffffffffff0000000000000000000000000000000000000000';

    test_receiveAndSendETH(_to, _bal, _val, _data);
  }

  function test_receiveAndSendETH_replicate_2() external {
    address payable _to = payable(address(0xCe71065D4017F316EC606Fe4422e11eB2c47c246));
    uint256 _bal = 1;
    uint256 _val = 1;
    bytes memory _data = hex'';

    test_receiveAndSendETH(_to, _bal, _val, _data);
  }

  function test_receiveAndSendETH_replicate_3() external {
    address payable _to = payable(address(0x004e59b44847b379578588920ca78fbf26c0b4956c));
    uint256 _bal = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 _val = 32005158966379385506248425894038775978611671383926508510093845911281980145664;
    bytes memory _data = hex'0000000000000000000000007109709ecfa91a80626ff3989d68f67f5b1dd12d';

    test_receiveAndSendETH(_to, _bal, _val, _data);
  }

  function test_receiveAndSendETH_replicate_4() external {
    address payable _to = payable(address(0x0000a329c0648769a73afac7f9381e08fb43dbea72));
    uint256 _bal = 19159689570456799670001278098056208385633235377719211981870697646817168850944;
    uint256 _val = 19159689570456799670001278098056208385633235377719211981870697646817168850944;
    bytes memory _data = hex'0cde000000000000000000000000000000000000000000000000000000000000';

    test_receiveAndSendETH(_to, _bal, _val, _data);
  }
}
