# Single node runner 
##Description
The folder contains 
- **Dockerfile** - builds required artifacts (gravity, solidity contract, orchestrator) from **onomyprotocol/gravity-bridge** master, 
install the required utils for the test-chain environment and copies scripts and assets to run the chain.
- **docker-compose.yml**  - template that might be used to run the chain and expose gravity and ethereum ports

## How to build & run
### Using docker compose
```
docker-compose down && docker-compose build && docker-compose up
```

## Entrypoints
- gravity swagger: [http://0.0.0.0:1317/swagger/](http://0.0.0.0:1317/swagger/)
- gravity rpc: [http://0.0.0.0:1317/](http://0.0.0.0:1317/)
- gravity grpc: [http://0.0.0.0:9090/](http://0.0.0.0:9090/)
- ethereum rpc: [http://0.0.0.0:8545/](http://0.0.0.0:8545/) | [geth API docs](https://geth.ethereum.org/docs/rpc/server)
