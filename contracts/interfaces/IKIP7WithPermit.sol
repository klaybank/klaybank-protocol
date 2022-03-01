// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IKIP7} from '../dependencies/openzeppelin/contracts/IKIP7.sol';

interface IKIP7WithPermit is IKIP7 {
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}
