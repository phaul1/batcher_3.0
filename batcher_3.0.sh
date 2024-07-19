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

transactions=()

while true; do
    echo_blue_bold "Enter transaction data (in hex) (or 'done' to finish):"
    read transactionData
    if [ "$transactionData" == "done" ]; then
        break
    fi

    echo_blue_bold "Enter gas limit:"
    read gasLimit
    echo
    echo_blue_bold "Enter gas price (in gwei):"
    read gasPrice
    echo
    echo_blue_bold "Enter number of transactions to send:"
    read numberOfTransactions
    echo
    echo_blue_bold "Is this a bridging transaction? (yes/no):"
    read isBridging
    if [ "$isBridging" == "yes" ]; then
        echo_blue_bold "Enter RPC URL of the destination network:"
        read destinationProviderURL
        echo
        echo_blue_bold "Enter destination contract address:"
        read destinationContractAddress
        echo
        transaction="{\"transactionData\":\"$transactionData\",\"gasLimit\":\"$gasLimit\",\"gasPrice\":\"$gasPrice\",\"numberOfTransactions\":\"$numberOfTransactions\",\"isBridging\":true,\"destinationProviderURL\":\"$destinationProviderURL\",\"destinationContractAddress\":\"$destinationContractAddress\"}"
    else
        transaction="{\"transactionData\":\"$transactionData\",\"gasLimit\":\"$gasLimit\",\"gasPrice\":\"$gasPrice\",\"numberOfTransactions\":\"$numberOfTransactions\",\"isBridging\":false}"
    fi
    transactions+=("$transaction")

    echo
done

if ! npm list -g ethers@5.5.4 >/dev/null 2>&1; then
  echo_blue_bold "Installing ethers..."
  npm install -g ethers@5.5.4
  echo
else
  echo_blue_bold "Ethers is already installed."
fi
echo

temp_node_file=$(mktemp /tmp/node_script.XXXXXX.js)

# Join transactions array into a JSON array string
transactions_json=$(printf ",%s" "${transactions[@]}")
transactions_json="[${transactions_json:1}]"

cat << EOF > $temp_node_file
const ethers = require("ethers");

const sourceProvider = new ethers.providers.JsonRpcProvider("${sourceProviderURL}");

const sourcePrivateKey = "${sourcePrivateKey}";

const sourceContractAddress = "${sourceContractAddress}";

const transactions = ${transactions_json};

async function sendTransaction(wallet, txDetails) {
    const tx = {
        to: txDetails.isBridging ? txDetails.destinationContractAddress : sourceContractAddress,
        value: 0,
        gasLimit: ethers.BigNumber.from(txDetails.gasLimit),
        gasPrice: ethers.utils.parseUnits(txDetails.gasPrice, 'gwei'),
        data: txDetails.transactionData,
    };

    try {
        const transactionResponse = await wallet.sendTransaction(tx);
        console.log("\033[1;35mTx Hash:\033[0m", transactionResponse.hash);
        const receipt = await transactionResponse.wait();
        console.log("");
    } catch (error) {
        console.error("Error sending transaction:", error);
    }
}

async function main() {
    const sourceWallet = new ethers.Wallet(sourcePrivateKey, sourceProvider);

    for (const txDetails of transactions) {
        if (txDetails.isBridging) {
            const destinationProvider = new ethers.providers.JsonRpcProvider(txDetails.destinationProviderURL);
            const destinationWallet = new ethers.Wallet(sourcePrivateKey, destinationProvider);

            for (let i = 0; i < txDetails.numberOfTransactions; i++) {
                console.log("Sending bridging transaction", i + 1, "of", txDetails.numberOfTransactions);
                await sendTransaction(destinationWallet, txDetails);
            }
        } else {
            for (let i = 0; i < txDetails.numberOfTransactions; i++) {
                console.log("Sending transaction", i + 1, "of", txDetails.numberOfTransactions);
                await sendTransaction(sourceWallet, txDetails);
            }
        }
    }
}

main().catch(console.error);
EOF

NODE_PATH=$(npm root -g):$(pwd)/node_modules node $temp_node_file

rm $temp_node_file
echo
echo_blue_bold "Stay Frosty DEGEN"
echo
