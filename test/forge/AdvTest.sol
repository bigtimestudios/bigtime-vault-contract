// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";


contract AdvTest is Test {

  // uint256 utils

  function min(uint256 _a, uint256 _b) internal pure returns (uint256) {
    return _a < _b ? _a : _b;
  }

  function max(uint256 _a, uint256 _b) internal pure returns (uint256) {
    return _a > _b ? _a : _b;
  }

  function boundDiff(uint256 _a, uint256 _b) internal pure returns (uint256) {
    if (_a != _b) return _a;

    return _b == type(uint256).max ? 0 : _b + 1;
  }

  function boundDiff(uint256 _a, uint256 _b, uint256 _c) internal pure returns (uint256) {
    uint256[] memory arr = new uint256[](2);
    arr[0] = _b;
    arr[1] = _c;
    return boundDiff(_a, arr);
  }

  function boundDiff(uint256 _a, uint256[] memory _b) internal pure returns (uint256) {
    unchecked {
      while (inSet(_a, _b)) {
        _a++;
      }

      return _a;
    }
  }

  function inSet(uint256 _a, uint256[] memory _b) internal pure returns (bool) {
    unchecked {
      for (uint256 i = 0; i < _b.length; i++) {
        if (_a == _b[i]) {
          return true;
        }
      }

      return false;
    }
  }

  // Address utils

  function boundPk(uint256 _a) internal pure returns (uint256) {
    if (_a > 0 && _a <= 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140) {
      return _a;
    }

    uint256 mod = _a % 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140;
    return 1 + mod;
  }

  function boundNoPrecompile(address _a) internal pure returns (address) {
    if (uint160(_a) > 0 && uint160(_a) < 10) {
      return address(10);
    }

    return _a;
  }

  function boundDiff(address _a, address _b) internal pure returns (address) {
    if (_a != _b) return _a;

    return address(uint160(_b) == type(uint160).max ? 0 : uint160(_b) + 1);
  }

  function boundDiff(address _a, address _b, address _c) internal pure returns (address) {
    address[] memory arr = new address[](2);
    arr[0] = _b;
    arr[1] = _c;
    return boundDiff(_a, arr);
  }

  function boundDiff(address _a, address _b, address _c, address _d) internal pure returns (address) {
    address[] memory arr = new address[](3);
    arr[0] = _b;
    arr[1] = _c;
    arr[2] = _d;
    return boundDiff(_a, arr);
  }

  function boundDiff(address _a, address _b, address _c, address _d, address _e) internal pure returns (address) {
    address[] memory arr = new address[](4);
    arr[0] = _b;
    arr[1] = _c;
    arr[2] = _d;
    arr[3] = _e;
    return boundDiff(_a, arr);
  }

  function boundDiff(address _a, address[] memory _b) internal pure returns (address) {
    unchecked {
      while (inSet(_a, _b)) {
        _a = address(uint160(_a) + 1);
      }

      return _a;
    }
  }

  function boundNoSys(address _a) internal view returns (address) {
    address[] memory arr = new address[](5);
    arr[0] = address(0x007109709ecfa91a80626ff3989d68f67f5b1dd12d);
    arr[1] = address(0x004e59b44847b379578588920ca78fbf26c0b4956c);
    arr[2] = address(0x00000000000000000000636f6e736f6c652e6c6f67);
    arr[3] = address(0x00ce71065d4017f316ec606fe4422e11eb2c47c246);
    arr[4] = address(this);

    _a = boundDiff(_a, arr);

    return boundNoPrecompile(_a);
  }

  function inSet(address _a, address[] memory _b) internal pure returns (bool) {
    unchecked {
      for (uint256 i = 0; i < _b.length; i++) {
        if (_a == _b[i]) {
          return true;
        }
      }

      return false;
    }
  }

  // Array utils

  function mayBoundArr(uint256 _size) internal returns (uint256) {
    try vm.envUint('MAX_ARRAY_LEN') returns (uint256 b) {
      return b == 0 ? _size : bound(_size, 0, b);
    } catch {
      return _size;
    }
  }

  function mayBoundArr(uint256[] memory _arr) internal returns (uint256[] memory) {
    uint256 size = _arr.length;
    uint256 boundSize = mayBoundArr(size);
    if (size == boundSize) {
      return _arr;
    }

    assembly {
      mstore(_arr, boundSize)
    }

    return _arr;
  }

  // Generic utils

  function replicate(bytes memory _calldata) internal {
    (bool success, bytes memory res) = address(this).call(_calldata);
    if (!success) {
      assembly {
        revert(add(res, 32), mload(res))
      }
    }
  }

  function boundChainId(uint256 _chainId) internal returns (uint256) {
    return bound(_chainId, 0, type(uint64).max);
  }
}
