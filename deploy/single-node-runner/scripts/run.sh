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

# TODO check if we need it
#echo "Copying genesis file around to sign"
#cp $n0cfgDir/genesis.json $n1cfgDir/genesis.json

echo "Generating ethereum keys"
# TODO set eth_key as variable
$gravity $home0 eth_keys add --output=json --dry-run=true | jq . >> $n0dir/eth_key.json

echo "Copying ethereum genesis file"
cp assets/ETHGenesis.json $home_dir

echo "Adding initial ethereum value"
jq ".alloc |= . + {$(jq .address $n0dir/eth_key.json) : {\"balance\": \"0x1337000000000000000000\"}}" $home_dir/ETHGenesis.json | sponge $home_dir/ETHGenesis.json

cat $home_dir/ETHGenesis.json

echo "Creating gentxs"
$gravity $home0 gentx --ip $n0name val 100000000000stake $(jq -r .address $n0dir/eth_key.json) $(jq -r .address $n0dir/orchestrator_key.json) $kbt $cid

echo "Collecting gentxs in $n0name"
# TODO check if we need it
#echo "Collecting gentxs in $n0name"
#cp $n1cfgDir/gentx/*.json $n0cfgDir/gentx/
$gravity $home0 collect-gentxs

# TODO check if we need it
#echo "Distributing genesis file into $n1name, $n2name, $n3name"
#cp $n0cfgDir/genesis.json $n1cfgDir/genesis.json


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

echo "Setting peers"
# TODO check if we need it
#peer0="$($gravity $home0 tendermint show-node-id)@$n0name:26656"

$gravity $home0 start --pruning=nothing > $CURRENT_WORKING_DIR/gravity.$n0name.log &>/dev/null

# TODO listen log
#cat $CURRENT_WORKING_DIR/gravity.$n0name.log

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
# TODO listen log
#cat $CURRENT_WORKING_DIR/ethereum.$n0name.log


