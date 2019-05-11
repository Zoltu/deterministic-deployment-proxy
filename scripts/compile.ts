import { promises as filesystem } from 'fs'
import * as path from 'path'
import { AbiFunction, AbiEvent } from 'ethereum'
import { CompilerOutput, CompilerInput, compileStandardWrapper, CompilerOutputContract } from 'solc'
import { rlpEncode } from '@zoltu/rlp-encoder'
import { keccak256 } from 'js-sha3'
import { ec as EllipticCurve } from 'elliptic'
const secp256k1 = new EllipticCurve('secp256k1')

export async function ensureDirectoryExists(absoluteDirectoryPath: string) {
	try {
		await filesystem.mkdir(absoluteDirectoryPath)
	} catch (error) {
		if (error.code === 'EEXIST') return
		throw error
	}
}

async function doStuff() {
	const compilerOutput = await compileContracts()
	const contract = compilerOutput.contracts['deterministic-deployment-proxy.sol']['DeterministicDeploymentProxy']
	await ensureDirectoryExists(path.join(__dirname, '..', '/output/'))
	await writeAbiJson(contract.abi)
	await writeBytecode(contract.evm.bytecode.object)
	await writeFactoryDeployerTransaction(contract)
}

async function compileContracts(): Promise<CompilerOutput> {
	const solidityFilePath = path.join(__dirname, '..', 'source', 'deterministic-deployment-proxy.sol')
	const soliditySourceCode = await filesystem.readFile(solidityFilePath, 'utf8')
	const compilerInput: CompilerInput = {
		language: "Solidity",
		settings: {
			optimizer: {
				enabled: true,
				runs: 500
			},
			outputSelection: {
				"*": {
					"*": [ "abi", "evm.bytecode.object", "evm.gasEstimates" ]
				}
			}
		},
		sources: {
			'deterministic-deployment-proxy.sol': {
				content: soliditySourceCode
			}
		}
	}
	const compilerInputJson = JSON.stringify(compilerInput)
	const compilerOutputJson = compileStandardWrapper(compilerInputJson)
	const compilerOutput = JSON.parse(compilerOutputJson) as CompilerOutput
	const errors = compilerOutput.errors
	if (errors) {
		let concatenatedErrors = "";

		for (let error of errors) {
			concatenatedErrors += error.formattedMessage + "\n";
		}

		if (concatenatedErrors.length > 0) {
			throw new Error("The following errors/warnings were returned by solc:\n\n" + concatenatedErrors);
		}
	}

	return compilerOutput
}

async function writeAbiJson(abi: (AbiFunction | AbiEvent)[]) {
	const filePath = path.join(__dirname, '../output/abi.json')
	const fileContents = JSON.stringify(abi, undefined, '\t')
	return await filesystem.writeFile(filePath, fileContents, { encoding: 'utf8', flag: 'w' })
}

async function writeBytecode(bytecode: string) {
	const filePath = path.join(__dirname, '..', 'output', `bytecode.txt`)
	await filesystem.writeFile(filePath, bytecode, { encoding: 'utf8', flag: 'w' })
}

async function writeFactoryDeployerTransaction(contract: CompilerOutputContract) {
	// https://github.com/ethereum/solidity/issues/6724 2x seems to be enough for this case... :this-is-fine:
	const deploymentGas = Number.parseInt(contract.evm.gasEstimates!.creation.totalCost) * 2
	const deploymentBytecode = contract.evm.bytecode.object

	const nonce = new Uint8Array(0)
	const gasPrice = arrayFromNumber(100*10**9)
	const gasLimit = arrayFromNumber(deploymentGas)
	const to = new Uint8Array(0)
	const value = new Uint8Array(0)
	const data = arrayFromHexString(deploymentBytecode)
	const v = arrayFromNumber(27)
	const r = arrayFromHexString('2222222222222222222222222222222222222222222222222222222222222222')
	const s = arrayFromHexString('2222222222222222222222222222222222222222222222222222222222222222')

	const unsignedEncodedTransaction = rlpEncode([nonce, gasPrice, gasLimit, to, value, data])
	const signedEncodedTransaction = rlpEncode([nonce, gasPrice, gasLimit, to, value, data, v, r, s])
	const hashedSignedEncodedTransaction = new Uint8Array(keccak256.arrayBuffer(unsignedEncodedTransaction))
	const signerAddress = arrayFromHexString(keccak256(secp256k1.recoverPubKey(hashedSignedEncodedTransaction, { r: r, s: s}, 0).encode('array').slice(1)).slice(-40))
	const contractAddress = arrayFromHexString(keccak256(rlpEncode([signerAddress, nonce])).slice(-40))

	const filePath = path.join(__dirname, '../output/deployment.json')
	const fileContents = `{
	"gasPrice": 100000000000,
	"gasLimit": ${deploymentGas},
	"signerAddress": "${signerAddress.reduce((x,y)=>x+=y.toString(16).padStart(2, '0'), '')}",
	"transaction": "${signedEncodedTransaction.reduce((x,y)=>x+=y.toString(16).padStart(2, '0'), '')}",
	"address": "${contractAddress.reduce((x,y)=>x+=y.toString(16).padStart(2, '0'), '')}"
}
`
	await filesystem.writeFile(filePath, fileContents, { encoding: 'utf8', flag: 'w' })
}

doStuff().then(() => {
	process.exit(0)
}).catch(error => {
	console.error(error)
	process.exit(1)
})

function arrayFromNumber(value: number): Uint8Array {
	return arrayFromHexString(value.toString(16))
}

function arrayFromHexString(value: string): Uint8Array {
	const normalized = (value.length % 2) ? `0${value}` : value
	const bytes = []
	for (let i = 0; i < normalized.length; i += 2) {
		bytes.push(Number.parseInt(`${normalized[i]}${normalized[i+1]}`, 16))
	}
	return new Uint8Array(bytes)
}
