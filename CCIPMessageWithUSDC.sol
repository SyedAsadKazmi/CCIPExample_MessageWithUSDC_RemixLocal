// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {HelperConfig} from "./HelperConfig.sol";

contract CCIPMessageWithUSDC is CCIPReceiver {
    error CCIPMessageWithUSDC__NotOwner();
    error CCIPMessageWithUSDC__NotFundedWithEnoughLINK();
    error CCIPMessageWithUSDC__InsufficientUSDCBalance();

    address private immutable i_owner;
    IERC20 private immutable i_usdcToken;
    LinkTokenInterface private immutable i_linkToken;
    IRouterClient private immutable i_routerForCCIP;

    string private s_lastReceivedMessage;
    uint256 private s_lastReceivedUSDC;
    HelperConfig private immutable i_helperConfig;

    event MessageSent(bytes32 indexed messageId);
    event MessageReceived(string receivedMessage, uint256 indexed receivedAmount);

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert CCIPMessageWithUSDC__NotOwner();
        }
        _;
    }

    constructor(address ccipRouterAddress) CCIPReceiver(ccipRouterAddress) {
        i_owner = msg.sender;
        i_routerForCCIP = IRouterClient(ccipRouterAddress);

        i_helperConfig = new HelperConfig();

        (address linkTokenAddress, address usdcTokenAddress) = i_helperConfig.activeNetworkConfig();

        i_usdcToken = IERC20(usdcTokenAddress);
        i_linkToken = LinkTokenInterface(linkTokenAddress);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        s_lastReceivedUSDC = message.destTokenAmounts[0].amount;
        if (message.data.length > 0) {
            s_lastReceivedMessage = abi.decode(message.data, (string));
        }
        emit MessageReceived(s_lastReceivedMessage, s_lastReceivedUSDC);
    }

    function publishMessageWithUSDC(
        string memory messageString,
        uint256 amountOfUsdc,
        uint64 destinationChainId,
        address destinationContractAddress
    ) external {
        s_lastReceivedMessage = "";
        s_lastReceivedUSDC = 0;

        bytes memory encodedMessage = abi.encode(messageString);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);

        if (amountOfUsdc > 0) {
            if (i_usdcToken.balanceOf(address(this)) < amountOfUsdc) {
                revert CCIPMessageWithUSDC__InsufficientUSDCBalance();
            }
            uint256 usdc_allowance = i_usdcToken.allowance(address(this), address(i_routerForCCIP));

            if (usdc_allowance < amountOfUsdc) {
                // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
                i_usdcToken.approve(address(i_routerForCCIP), amountOfUsdc);
            }
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({token: address(i_usdcToken), amount: amountOfUsdc});
        }

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationContractAddress),
            data: encodedMessage,
            tokenAmounts: tokenAmounts,
            extraArgs: "",
            feeToken: address(i_linkToken)
        });

        uint256 fee = IRouterClient(i_routerForCCIP).getFee(
            i_helperConfig.getDestinationChainSelector(destinationChainId), message
        );

        if (i_linkToken.balanceOf(address(this)) < fee) {
            revert CCIPMessageWithUSDC__NotFundedWithEnoughLINK();
        }

        uint256 allowance = i_linkToken.allowance(address(this), address(i_routerForCCIP));

        if (allowance < fee) {
            i_linkToken.approve(address(i_routerForCCIP), fee);
        }

        bytes32 messageId = IRouterClient(address(i_routerForCCIP)).ccipSend(
            i_helperConfig.getDestinationChainSelector(destinationChainId), message
        );

        emit MessageSent(messageId);
    }

    function withdrawUSDC() external onlyOwner {
        i_usdcToken.transfer(msg.sender, i_usdcToken.balanceOf(address(this)));
    }

    function withdrawLINK() external onlyOwner {
        i_linkToken.transfer(msg.sender, i_linkToken.balanceOf(address(this)));
    }

    /* GETTERS */

    function getCurrentNetworkName() external view returns (string memory networkName) {
        if (block.chainid == 80002) {
            networkName = "Polygon Amoy";
        } else if (block.chainid == 43113) {
            networkName = "Avalanche Fuji";
        } else if (block.chainid == 11155111) {
            networkName = "Ethereum Sepolia";
        } else if (block.chainid == 84532) {
            networkName = "Base Sepolia";
        }
    }

    function getActiveNetworkConfig() external view returns (address, address) {
        return i_helperConfig.activeNetworkConfig();
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getLastReceivedMessage() external view returns (string memory) {
        return s_lastReceivedMessage;
    }

    function getLastReceivedUSDC() external view returns (uint256) {
        return s_lastReceivedUSDC;
    }

    function getBalanceOfUSDC() external view returns (uint256) {
        return i_usdcToken.balanceOf(address(this));
    }

    function getBalanceOfLINK() external view returns (uint256) {
        return i_linkToken.balanceOf(address(this));
    }
}
