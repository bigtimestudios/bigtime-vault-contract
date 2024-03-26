// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/receiver/ReceiverHub.sol";

import "test/forge/AdvTest.sol";


contract ReceiverHubImp is ReceiverHub {
  function execute(uint256 _id, address _to, uint256 _value, bytes calldata _data) external returns (bytes memory) {
    return executeOnReceiver(_id, _to, _value, _data);
  }
}

contract RevertsMock {
  error Reverted(address _sender, uint256 _value, bytes _data);

  receive() external payable { revert Reverted(msg.sender, msg.value, hex''); }
  fallback() external payable { revert Reverted(msg.sender, msg.value, msg.data); }
}

contract ExpectCallMock {
  bytes private lastData;
  address private lastCaller;
  uint256 private lastValue;
  address private immutable creator;

  constructor () {
    creator = msg.sender;
  }

  receive() external payable { react(); }
  fallback(bytes calldata) external payable returns (bytes memory) { return react(); }

  function react() internal returns (bytes memory) {
    if (msg.sender != creator) {
      lastData = msg.data;
      lastCaller = msg.sender;
      lastValue = msg.value;
    }

    bytes memory result = abi.encode(lastCaller, lastValue, lastData);
    return result;
  }
}

library ReadCallMock {
  function readAll(ExpectCallMock _mock) internal returns (bytes memory) {
    (bool suc, bytes memory res) = address(_mock).call(hex'00');
    assert(suc);
    return res;
  }

  function lastData(ExpectCallMock _mock) internal returns (bytes memory) {
    (,,bytes memory ld) = abi.decode(ReadCallMock.readAll(_mock), (address, uint256, bytes));
    return ld;
  }

  function lastCaller(ExpectCallMock _mock) internal returns (address) {
    (address lc,,) = abi.decode(ReadCallMock.readAll(_mock), (address, uint256, bytes));
    return lc;
  }

  function lastValue(ExpectCallMock _mock) internal returns (uint256) {
    (,uint256 lv,) = abi.decode(ReadCallMock.readAll(_mock), (address, uint256, bytes));
    return lv;
  }
}

contract ReceiverHubTest is AdvTest {
  using ReadCallMock for ExpectCallMock;

  ReceiverHubImp hub;

  function setUp() public {
    hub = new ReceiverHubImp();
  }

  function test_createOnExecute(uint256 _id, address _to, bytes memory _data) public {
    _to = boundDiff(boundDiff(boundNoSys(_to), address(this)), address(hub));

    Receiver expected = hub.receiverFor(_id);
    hub.execute(_id, _to, 0, _data);

    assertTrue(address(expected).code.length != 0);
  }

  function test_createOnExecute_replicate1() external {
    test_createOnExecute(
      90707046314383479744563083578895649291083642128492652145305604879531068358656,
      address(0x007109709ecfa91a80626ff3989d68f67f5b1dd12d),
      hex"05a9000000000000000000000000000000000000000000000000000000000000"
    );
  }

  function test_executeOnce(uint256 _id, address _to, bytes memory _data) public {
    _to = boundDiff(boundDiff(boundNoSys(_to), address(this)), address(hub));

    vm.expectCall(_to, _data);
    hub.execute(_id, _to, 0, _data);
  }

  function test_executeOnce_replicate1() external {
    uint256 _id = 31411796921297243887308112356096044848790705097401522080818137395660099774830;
    address _to = address(0x037FC82298142374d974839236D2e2dF6B5BdD8F);
    bytes memory _data = hex'00';
    test_executeOnce(_id, _to, _data);
  }

  function test_executeTwice(
    uint256 _id,
    address _to1,
    address _to2,
    bytes memory _data1,
    bytes memory _data2
  ) public {
    address receiver = address(hub.receiverFor(_id));
    address template = hub.receiverTemplate();

    _to1 = boundDiff(boundNoSys(_to1), address(this), address(hub), receiver, template);
    _to2 = boundDiff(boundNoSys(_to2), address(this), address(hub), receiver, template);

    vm.expectCall(_to1, _data1);
    hub.execute(_id, _to1, 0, _data1);

    vm.expectCall(_to2, _data2);
    hub.execute(_id, _to2, 0, _data2);
  }

  function test_executeTwice_replicate1() external {
    test_executeTwice(
      34626061421848258521560170161043836694947213713378829347250384030801068032,
      address(0x00037fc82298142374d974839236d2e2df6b5bdd8f),
      address(0x00422e11eb2c47c246000000000000000000000000),
      bytes(hex'150b7a0200000000000000000000000000000000000000000000000000000000'),
      bytes(hex'003d7d0000000000000000000000000000000000000000000000000000000000')
    );
  }


  function test_multipleReceivers(
    uint256 _id1,
    uint256 _id2,
    bytes memory _data1,
    bytes memory _data2
  ) public {
    ExpectCallMock to = new ExpectCallMock();

    hub.execute(_id1, address(to), 0, _data1);
    assertEq(to.lastCaller(), address(hub.receiverFor(_id1)));
    assertEq(to.lastData(), _data1);

    hub.execute(_id2, address(to), 0, _data2);
    assertEq(to.lastCaller(), address(hub.receiverFor(_id2)));
    assertEq(to.lastData(), _data2);
  }

  function test_multipleReceivers_replicate1() external {
    uint256 id1 = 6101143770562858388092324182252890499966780331398621714763671413838577664;
    uint256 id2 = 97217999040891881509805971076034180523226320981992065016019316216436883456;
    bytes memory data1 = hex'0003740000000000000000000000000000000000000000000000000000000000';
    bytes memory data2 = hex'4318383400000000000000000000000000000000000000000000000000000000';
    test_multipleReceivers(id1, id2, data1, data2);
  }

  function test_executeFromReceiver(uint256 _id, uint256 _val, bytes calldata _data) external {
    address receiver = address(hub.receiverFor(_id));

    ExpectCallMock to = new ExpectCallMock();

    vm.deal(receiver, _val);
    hub.execute(_id, address(to), _val, _data);

    assertEq(to.lastCaller(), receiver);
    assertEq(to.lastValue(), _val);
    assertEq(to.lastData(), _data);
  }

  function test_executeFromReceiverTwice(
    uint256 _id,
    uint256 _val1,
    uint256 _val2,
    bytes memory _data1,
    bytes memory _data2
  ) public {
    _val1 = bound(_val1, 0, type(uint256).max - _val2);

    address receiver = address(hub.receiverFor(_id));

    ExpectCallMock to = new ExpectCallMock();

    vm.deal(receiver, _val1 + _val2);

    hub.execute(_id, address(to), _val1, _data1);

    assertEq(to.lastCaller(), receiver);
    assertEq(to.lastValue(), _val1);
    assertEq(to.lastData(), _data1);

    hub.execute(_id, address(to), _val2, _data2);

    assertEq(to.lastCaller(), receiver);
    assertEq(to.lastValue(), _val2);
    assertEq(to.lastData(), _data2);
  }

  function test_executeFromReceiverTwice_replicate1() external {
    uint256 id = 131243608530569360981859317477059916003810288214792070732970560639767412736;
    uint256 val1 = 89674390283849795290139782918565391703697258875409832511226677239824252928;
    uint256 val2 = 742075767206921418424984950312025776647543236687759962411074604542900305920;
    bytes memory data1 = hex'000f840000000000000000000000000000000000000000000000000000000000';
    bytes memory data2 = hex'f18d94ca00000000000000000000000000000000000000000000000000000000';
    test_executeFromReceiverTwice(id, val1, val2, data1, data2);
  }


  function test_revertCall(uint256 _id, uint256 _val, bytes calldata _data) external {
    RevertsMock to = new RevertsMock();

    address receiver = address(hub.receiverFor(_id));
    vm.deal(receiver, _val);

    bytes memory nestedErr = abi.encodeWithSignature("Reverted(address,uint256,bytes)", receiver, _val, _data);
    bytes memory err = abi.encodeWithSignature(
      "ReceiverCallError(address,address,uint256,bytes,bytes)",
      receiver, address(to), _val, _data, nestedErr
    );

    vm.expectRevert(err);
    hub.execute(_id, address(to), _val, _data);
  }
}
