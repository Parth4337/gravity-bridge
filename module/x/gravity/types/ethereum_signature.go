package types

import "github.com/ethereum/go-ethereum/common"

var (
	_ EthereumSignature = &UpdateSignerSetTxSignature{}
	_ EthereumSignature = &ContractCallTxSignature{}
	_ EthereumSignature = &BatchTxSignature{}
)

///////////////
// GetSigner //
///////////////

func (u *UpdateSignerSetTxSignature) GetSigner() common.Address {
	return common.HexToAddress(u.EthereumSigner)
}

func (u *ContractCallTxSignature) GetSigner() common.Address {
	return common.HexToAddress(u.EthereumSigner)
}

func (u *BatchTxSignature) GetSigner() common.Address {
	return common.HexToAddress(u.EthereumSigner)
}

///////////////////
// GetStoreIndex //
///////////////////

func (u *UpdateSignerSetTxSignature) GetStoreIndex() []byte {
	panic("NOT IMPLEMENTED")
}

func (u *ContractCallTxSignature) GetStoreIndex() []byte {
	panic("NOT IMPLEMENTED")
}

func (u *BatchTxSignature) GetStoreIndex() []byte {
	panic("NOT IMPLEMENTED")
}

//////////////
// Validate //
//////////////

func (u *UpdateSignerSetTxSignature) Validate() error {
	panic("NOT IMPLEMENTED")
}

func (u *ContractCallTxSignature) Validate() error {
	panic("NOT IMPLEMENTED")
}

func (u *BatchTxSignature) Validate() error {
	panic("NOT IMPLEMENTED")
}