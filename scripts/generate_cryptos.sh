#!/bin/sh

source $(pwd)/.env

# echoc: Prints the user specified string to the screen using the specified colour.
#
# Parameters: ${1} - The string to print.
#             ${2} - The intensity of the colour.
#             ${3} - The colour to use for printing the string.
#
#             NOTE: The following color options are available:
#
#                   [0|1]30, [dark|light] black
#                   [0|1]31, [dark|light] red
#                   [0|1]32, [dark|light] green
#                   [0|1]33, [dark|light] brown
#                   [0|1]34, [dark|light] blue
#                   [0|1]35, [dark|light] purple
#                   [0|1]36, [dark|light] cyan
#
 echoc() {
    # Check for proper usage
    if [[ ${#} != 3 ]]; then
        echo "usage: ${FUNCNAME} <string> [light|dark] [black|red|green|brown|blue|pruple|cyan]"
        exit 1
    fi

    local message=${1}

    case $2 in
        dark )
            intensity=0
            ;;
        light )
            intensity=1
            ;;
    esac

    if [[ -z $intensity ]]; then
        echo "${2} intensity not recognised"
        exit 1
    fi

    case $3 in 
        black )
            colour_code=${intensity}30
            ;;
        red )
            colour_code=${intensity}31
            ;;
        green )
            colour_code=${intensity}32
            ;;
        brown )
            colour_code=${intensity}33
            ;;
        blue )
            colour_code=${intensity}34
            ;;
        purple )
            colour_code=${intensity}35
            ;;
        cyan )
            colour_code=${intensity}36
            ;;
    esac
        
    if [[ -z $colour_code ]]; then
        echo "${1} colour not recognised"
        exit 1
    fi

    colour_code=${colour_code:1}

    # Print out the message
    echo "${message}" | awk '{print "\033['${intensity}';'${colour_code}'m" $0 "\033[1;0m"}'
}

# generate genesis block
# $1: base path
# $2: config path
# $3: cryptos directory
generate_genesis() {
    if [ -z "$1" ]; then
		echoc "Base path missing" light red
		exit 1
	fi
    if [ -z "$2" ]; then
		echoc "Config path missing" light red
		exit 1
	fi
    if [ -z "$3" ]; then
		echoc "Crypto material path missing" light red
		exit 1
	fi

    local base_path="$1"
    local config_path="$2"
    local channel_dir="${base_path}/channels/orderer-system-channel"
    local cryptos_path="$3"
    local network_profile="$4"

    echoc "Generating genesis block" light cyan
	echoc "Base path: $base_path" light green
	echoc "Config path: $config_path" light green
	echoc "Cryptos path: $cryptos_path" light green
	echoc "Network profile: $network_profile" light green

    if [ -d "$channel_dir" ]; then
        rm -rf $channel_dir
    fi
    mkdir -p $channel_dir

    # generate genesis block for orderer
	docker run --rm -v ${config_path}/configtx.yaml:/configtx.yaml \
                    -v ${channel_dir}:/channels/orderer-system-channel \
                    -v ${cryptos_path}:/crypto-config \
                    -e FABRIC_CFG_PATH=/ \
                    hyperledger/fabric-tools:$FABRIC_TAG \
                    bash -c " \
                        configtxgen -profile $network_profile -channelID orderer-system-channel -outputBlock /channels/orderer-system-channel/genesis_block.pb /configtx.yaml;
                        configtxgen -inspectBlock /channels/orderer-system-channel/genesis_block.pb
                    "
	if [ "$?" -ne 0 ]; then
		echoc "Failed to generate orderer genesis block..." light red
		exit 1
	fi
}

# generate channel config
# $1: channel_name
# $2: base path
# $3: configtx.yml file path
# $4: cryptos directory
# $5: network profile name
# $6: channel profile name
# $7: org msp
generate_channeltx() {
    if [ -z "$1" ]; then
		echoc "Channel name missing" light red
		exit 1
	fi
    if [ -z "$2" ]; then
		echoc "Base path missing" light red
		exit 1
	fi
    if [ -z "$3" ]; then
		echoc "Config path missing" light red
		exit 1
	fi
    if [ -z "$4" ]; then
		echoc "Crypto material path missing" light red
		exit 1
	fi
    if [ -z "$5" ]; then
		echoc "Network profile missing" light red
		exit 1
	fi
    if [ -z "$6" ]; then
		echoc "Channel profile missing" light red
		exit 1
	fi
    if [ -z "$7" ]; then
		echoc "MSP missing" light red
		exit 1
	fi

	local channel_name="$1"
    local base_path="$2"
    local config_path="$3"
    local cryptos_path="$4"
    local channel_dir="${base_path}/channels/${channel_name}"
    local network_profile="$5"
    local channel_profile="$6"
    local org_msp="$7"

    if [ -d "$channel_dir" ]; then
        rm -rf $channel_dir
    fi
    mkdir -p $channel_dir

    echoc "Generating channel config" light cyan
	echoc "Channel: $channel_name" light green
	echoc "Base path: $base_path" light green
	echoc "Config path: $config_path" light green
	echoc "Cryptos path: $cryptos_path" light green
	echoc "Channel dir: $channel_dir" light green
	echoc "Network profile: $network_profile" light green
	echoc "Channel profile: $channel_profile" light green
	echoc "Org MSP: $org_msp" light green

	# generate channel configuration transaction
	docker run --rm -v ${config_path}/configtx.yaml:/configtx.yaml \
                    -v ${channel_dir}:/channels/${channel_name} \
                    -v ${cryptos_path}:/crypto-config \
                    -e FABRIC_CFG_PATH=/ \
                    hyperledger/fabric-tools:$FABRIC_TAG \
                    bash -c " \
                        configtxgen -profile $channel_profile -outputCreateChannelTx /channels/${channel_name}/${channel_name}_tx.pb -channelID $channel_name /configtx.yaml;
                        configtxgen -inspectChannelCreateTx /channels/${channel_name}/${channel_name}_tx.pb
                    "
	if [ "$?" -ne 0 ]; then
		echoc "Failed to generate channel configuration transaction..." light red
		exit 1
	fi

	# generate anchor peer transaction
	docker run --rm -v ${config_path}/configtx.yaml:/configtx.yaml \
                    -v ${channel_dir}:/channels/${channel_name} \
                    -v ${cryptos_path}:/crypto-config \
                    -e FABRIC_CFG_PATH=/ \
                    hyperledger/fabric-tools:$FABRIC_TAG \
                    configtxgen -profile $channel_profile -outputAnchorPeersUpdate /channels/${channel_name}/${org_msp}_anchors_tx.pb -channelID $channel_name -asOrg $org_msp /configtx.yaml
	if [ "$?" -ne 0 ]; then
		echoc "Failed to generate anchor peer update for $org_msp..." light red
		exit 1
	fi
}

# generate crypto config
# $1: crypto-config.yml file path
# $2: certificates output directory
generate_cryptos() {
    if [ -z "$1" ]; then
		echoc "Config path missing" light red
		exit 1
	fi
    if [ -z "$2" ]; then
		echoc "Cryptos path missing" light red
		exit 1
	fi

    local config_path="$1"
    local cryptos_path="$2"

    if [ -d "$cryptos_path" ]; then
        rm -rf $cryptos_path
    fi
    mkdir -p $cryptos_path

    echoc "Generating cryptos" light cyan
	echoc "Config path: $config_path" light green
	echoc "Cryptos path: $cryptos_path" light green

	# generate crypto material
	docker run --rm -v ${config_path}/crypto-config.yaml:/crypto-config.yaml \
                    -v ${cryptos_path}:/crypto-config \
                    hyperledger/fabric-tools:$FABRIC_TAG \
                    cryptogen generate --config=/crypto-config.yaml --output=/crypto-config
	if [ "$?" -ne 0 ]; then
		echoc "Failed to generate crypto material..." light red
		exit 1
	fi
}

generate_cryptos $CONFIG_PATH $CRYPTOS_PATH
generate_genesis $BASE_PATH $CONFIG_PATH $CRYPTOS_PATH OneOrgOrdererGenesis
generate_channeltx private $BASE_PATH $CONFIG_PATH $CRYPTOS_PATH OneOrgOrdererGenesis OneOrgChannel Org1MSP
generate_channeltx trading $BASE_PATH $CONFIG_PATH $CRYPTOS_PATH OneOrgOrdererGenesis OneOrgChannel Org1MSP
generate_channeltx sharing $BASE_PATH $CONFIG_PATH $CRYPTOS_PATH OneOrgOrdererGenesis OneOrgChannel Org1MSP