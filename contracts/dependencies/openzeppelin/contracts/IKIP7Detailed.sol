// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IKIP7} from './IKIP7.sol';

interface IKIP7Detailed is IKIP7 {
  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);
}
