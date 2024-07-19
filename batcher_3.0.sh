#!/bin/bash

function echo_blue_bold {
    echo -e "\033[1;34m$1\033[0m"
}

# Function to install Node.js if not installed
function install_node {
    if ! command -v node &> /dev/null
    then
        echo_blue_bold "Node.js not found. Installing Node.js..."
        curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
}

# Function to install npm if not installed
function install_npm {
    if ! command -v npm &> /dev/null
    then
        echo_blue_bold "npm not found. Installing npm..."
        sudo apt install -y npm
    fi
}

# Ensure Node.js and npm are installed
install_node
install_npm

echo
echo_blue_bold "Enter RPC URL of the source network:"
read sourceProviderURL
echo
echo_blue_bold "Enter private key for the source network:"
read sourcePrivateKey
echo
echo_blue_bold "Enter source contract address:"
read sourceContractAddress
echo
echo_blue_bold "Enter source transaction data (in hex):"
read sourceTransactionData
echo
echo_blue_bold "Enter gas limit for source transaction:"
read sourceGasLimit
echo
echo_blue_bold "Enter gas price for source transaction (in gwei):"
read sourceGasPrice
echo
echo_blue_bold "Enter number of transactions to send:"
read numberOfTransactions
echo
echo_blue_bold "Enter RPC URL of the destination network:"
read destinationProviderURL
echo
echo_blue_bold "Enter destination contract address:"
read destinationContractAddress
echo
echo_blue_bold "Enter destination transaction data (in hex):"
read destinationTransactionData
echo
echo_blue_bold "Enter gas limit for destination transaction:"
read destinationGasLimit
echo
echo_blue_bold "Enter gas price for destination transaction (in gwei):"
read destinationGasPrice
echo

if ! npm list -g ethers@5.5.4 >/dev/null 2>&1; then
  echo_blue_bold "Installing ethers..."
  npm install -g ethers@5.5.4
  echo
else
  echo_blue_bold "Ethers is already installed."
fi
echo

temp_node_file=$(mktemp /tmp/node_script.XXXXXX.js)

cat << EOF > $temp_node_file
const ethers = require("ethers");

const sourceProvider = new ethers.providers.JsonRpcProvider("${sourceProviderURL}");
const destinationProvider = new ethers.providers.JsonRpcProvider("${destinationProviderURL}");

const sourcePrivateKey = "${sourcePrivateKey}";

const sourceContractAddress = "${sourceContractAddress}";
const destinationContractAddress = "${destinationContractAddress}";

const sourceTransactionData = "${sourceTransactionData}";
const sourceGasLimit = "${sourceGasLimit}";
const sourceGasPrice = "${sourceGasPrice}";

const destinationTransactionData = "${destinationTransactionData}";
const destinationGasLimit = "${destinationGasLimit}";
const destinationGasPrice = "${destinationGasPrice}";

const numberOfTransactions = ${numberOfTransactions};

async function sendTransaction(wallet, contractAddress, txData, gasLimit, gasPrice) {
    const tx = {
        to: contractAddress,
        value: 0,
        gasLimit: ethers.BigNumber.from(gasLimit),
        gasPrice: ethers.utils.parseUnits(gasPrice, 'gwei'),
        data: txData,
    };

    try {
        const transactionResponse = await wallet.sendTransaction(tx);
        console.log("\033[1;35mTx Hash:\033[0m", transactionResponse.hash);
        const receipt = await transactionResponse.wait();
        console.log("Transaction successful with receipt:", receipt);
        console.log("");
    } catch (error) {
        console.error("Error sending transaction:", error);
        console.error("Transaction details:", tx);
    }
}

async function main() {
    const sourceWallet = new ethers.Wallet(sourcePrivateKey, sourceProvider);
    const destinationWallet = new ethers.Wallet(sourcePrivateKey, destinationProvider);

    for (let i = 0; i < numberOfTransactions; i++) {
        console.log("Sending bridging transaction", i + 1, "of", numberOfTransactions);
        await sendTransaction(sourceWallet, sourceContractAddress, sourceTransactionData, sourceGasLimit, sourceGasPrice);
        await sendTransaction(destinationWallet, destinationContractAddress, destinationTransactionData, destinationGasLimit, destinationGasPrice);
    }
}

main().catch(console.error);
EOF

NODE_PATH=$(npm root -g):$(pwd)/node_modules node $temp_node_file

rm $temp_node_file
echo
echo_blue_bold "Stay Frosty DEGEN"
echo
