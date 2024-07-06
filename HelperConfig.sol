// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CCIPLocalSimulator, IRouterClient, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {MockUSDC} from "./local/MockUSDC.sol";

contract HelperConfig {
    error HelperConfig__NetworkNotSupported();

    struct NetworkConfig {
        address linkTokenAddress;
        address usdcTokenAddress;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 80002) {
            activeNetworkConfig = getPolygonAmoyConfig();
        } else if (block.chainid == 43113) {
            activeNetworkConfig = getPolygonAmoyConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getAvalancheFujiConfig();
        } else if (block.chainid == 84532) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateLocalNetworkConfig();
        }
    }

    function getPolygonAmoyConfig() internal pure returns (NetworkConfig memory polygonAmoyConfig) {
        polygonAmoyConfig = NetworkConfig({
            linkTokenAddress: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904,
            usdcTokenAddress: 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582
        });
    }

    function getAvalancheFujiConfig() internal pure returns (NetworkConfig memory avalancheFujiConfig) {
        avalancheFujiConfig = NetworkConfig({
            linkTokenAddress: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
            usdcTokenAddress: 0x5425890298aed601595a70AB815c96711a31Bc65
        });
    }

    function getEthereumSepoliaConfig() internal pure returns (NetworkConfig memory ethereumSepoliaConfig) {
        ethereumSepoliaConfig = NetworkConfig({
            linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            usdcTokenAddress: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
        });
    }

    function getBaseSepoliaConfig() internal pure returns (NetworkConfig memory baseSepoliaConfig) {
        baseSepoliaConfig = NetworkConfig({
            linkTokenAddress: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
            usdcTokenAddress: 0x036CbD53842c5426634e7929541eC2318f3dCF7e
        });
    }

    function getOrCreateLocalNetworkConfig() internal returns (NetworkConfig memory localNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.linkTokenAddress != address(0)) {
            return activeNetworkConfig;
        }

        CCIPLocalSimulator ccipLocalSimulator = new CCIPLocalSimulator();

        (,,,, LinkToken linkToken,,) = ccipLocalSimulator.configuration();

        localNetworkConfig =
            NetworkConfig({linkTokenAddress: address(linkToken), usdcTokenAddress: address(new MockUSDC())});
        return localNetworkConfig;
    }

    function getDestinationChainSelector(uint256 chainId) external pure returns (uint64 destinationChainSelector) {
        if (chainId == 80002) {
            destinationChainSelector = 16281711391670634445;
        } else if (chainId == 43113) {
            destinationChainSelector = 14767482510784806043;
        } else if (chainId == 11155111) {
            destinationChainSelector = 16015286601757825753;
        } else if (chainId == 84532) {
            destinationChainSelector = 10344971235874465080;
        } else {
            revert HelperConfig__NetworkNotSupported();
        }
    }
}
