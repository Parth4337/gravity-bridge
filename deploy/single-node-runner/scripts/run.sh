#!/bin/bash
set -eu

echo "bootstrapping environment"

# Constants
CURRENT_WORKING_DIR=$(pwd)
CHAINID="testchain"
CHAINDIR="$CURRENT_WORKING_DIR/testdata"
gravity=gravity
#FED=oracle-feeder
home_dir="$CHAINDIR/$CHAINID"

n0name="gravity0"
# Folders for nodes
n0dir="$home_dir/$n0name"
# Home flag for folder
home0="--home $n0dir"
# Config directories for nodes
n0cfgDir="$n0dir/config"
# Config files for nodes
n0cfg="$n0cfgDir/config.toml"
# App config files for nodes
n0appCfg="$n0cfgDir/app.toml"
# Common flags
kbt="--keyring-backend test"
cid="--chain-id $CHAINID"

echo "Creating $gravity validator with chain-id=$CHAINID..."
echo "Initializing genesis files"

# Build genesis file incl account for passed address
coins="100000000000stake,100000000000samoleans"

# Initialize the home directory and add some keys
$gravity $home0 $cid init n0
$gravity $home0 keys add val $kbt --output json | jq . >> $n0dir/validator_key.json

echo "Adding validator addresses to genesis files"
$gravity $home0 add-genesis-account $($gravity $home0 keys show val -a $kbt) $coins

echo "Generating orchestrator keys"
$gravity $home0 keys add --dry-run=true --output=json orch | jq . >> $n0dir/orchestrator_key.json

echo "Adding orchestrator keys to genesis"
n0orchKey="$(jq .address $n0dir/orchestrator_key.json)"

jq ".app_state.auth.accounts += [{\"@type\": \"/cosmos.auth.v1beta1.BaseAccount\",\"address\": $n0orchKey,\"pub_key\": null,\"account_number\": \"0\",\"sequence\": \"0\"}]" $n0cfgDir/genesis.json | sponge $n0cfgDir/genesis.json
jq ".app_state.bank.balances += [{\"address\": $n0orchKey,\"coins\": [{\"denom\": \"samoleans\",\"amount\": \"100000000000\"},{\"denom\": \"stake\",\"amount\": \"100000000000\"}]}]" $n0cfgDir/genesis.json | sponge $n0cfgDir/genesis.json

echo "Generating ethereum keys"
$gravity $home0 eth_keys add --output=json --dry-run=true | jq . >> $n0dir/eth_key.json

echo "Copying ethereum genesis file"
cp assets/ETHGenesis.json $home_dir

echo "Adding initial ethereum value"
jq ".alloc |= . + {$(jq .address $n0dir/eth_key.json) : {\"balance\": \"0x1337000000000000000000\"}}" $home_dir/ETHGenesis.json | sponge $home_dir/ETHGenesis.json

echo "Creating gentxs"
$gravity $home0 gentx --ip $n0name val 100000000000stake $(jq -r .address $n0dir/eth_key.json) $(jq -r .address $n0dir/orchestrator_key.json) $kbt $cid

echo "Collecting gentxs in $n0name"
$gravity $home0 collect-gentxs

echo "Exposing ports and APIs of the $n0name"
# Switch sed command in the case of linux
fsed() {
  if [ `uname` = 'Linux' ]; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Change ports on n0 val
fsed "s#\"tcp://127.0.0.1:26656\"#\"tcp://0.0.0.0:26656\"#g" $n0cfg
fsed "s#\"tcp://127.0.0.1:26657\"#\"tcp://0.0.0.0:26657\"#g" $n0cfg
fsed 's#addr_book_strict = true#addr_book_strict = false#g' $n0cfg
fsed 's#external_address = ""#external_address = "tcp://'$n0name:26656'"#g' $n0cfg
fsed 's#enable = false#enable = true#g' $n0appCfg
fsed 's#swagger = false#swagger = true#g' $n0appCfg

$gravity $home0 start --pruning=nothing > $CURRENT_WORKING_DIR/gravity.$n0name.log &>/dev/null

#-------------------- Ethereum --------------------

geth --identity "GravityTestnet" \
    --nodiscover \
    --networkid 15 init assets/ETHGenesis.json

geth --identity "GravityTestnet" --nodiscover \
                               --networkid 15 \
                               --mine \
                               --http \
                               --http.port "8545" \
                               --http.addr "0.0.0.0" \
                               --http.corsdomain "*" \
                               --http.vhosts "*" \
                               --miner.threads=1 \
                               --nousb \
                               --verbosity=5 \
                               --miner.etherbase=0xBf660843528035a5A4921534E156a27e64B231fE \
                               > $CURRENT_WORKING_DIR/ethereum.$n0name.log &>/dev/null

#-------------------- Ethereum / Applying contracts --------------------

echo "Waiting for nodes"
sleep 10

echo "Applying contracts"

GRAVITY_DIR=/go/src/github.com/onomyprotocol/gravity-bridge/
cd $GRAVITY_DIR/solidity

contractAddress=$(npx ts-node \
                      contract-deployer.ts \
                      --cosmos-node="http://$n0name:26657" \
                      --eth-node="http://0.0.0.0:8545" \
                      --eth-privkey="0xb1bab011e03a9862664706fc3bbaa1b16651528e5f0e7fbfcbfdd8be302a13e7" \
                      --contract=artifacts/contracts/Gravity.sol/Gravity.json \
                      --test-mode=true | grep "Gravity deployed at Address" | grep -Eow '0x[0-9a-fA-F]{40}')

echo "Contract address: $contractAddress"

# return back to home
cd $CURRENT_WORKING_DIR

#-------------------- ORCHESTRATOR --------------------

echo "Gathering keys for orchestrators"
VALIDATOR=$n0name
COSMOS_GRPC="http://$n0name:9090/"
COSMOS_RPC="http://$n0name:1317"
COSMOS_KEY=$(jq .priv_key.value $n0cfgDir/priv_validator_key.json)
COSMOS_PHRASE=$(jq .mnemonic $n0dir/orchestrator_key.json)
DENOM=stake
ETH_RPC=http://0.0.0.0:8545
ETH_PRIVATE_KEY=$(jq .private_key $n0dir/eth_key.json)
CONTRACT_ADDR=$contractAddress

rpc="http://0.0.0.0:1317"
grpc="http://0.0.0.0:9090"
ethrpc="http://0.0.0.0:8545"

echo orchestrator --cosmos-phrase="${COSMOS_PHRASE}" \
             --ethereum-key="${ETH_PRIVATE_KEY}" \
             --cosmos-grpc="$grpc" \
             --ethereum-rpc="$ethrpc" \
             --fees="${DENOM}" \
             --contract-address="${CONTRACT_ADDR}"\
             --address-prefix=cosmos

orchestrator --cosmos-phrase="${COSMOS_PHRASE}" \
             --ethereum-key="${ETH_PRIVATE_KEY}" \
             --cosmos-grpc="$grpc" \
             --ethereum-rpc="$ethrpc" \
             --fees="${DENOM}" \
             --contract-address="${CONTRACT_ADDR}"\
             --address-prefix=cosmos

echo "done"