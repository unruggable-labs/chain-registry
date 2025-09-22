/**
 * @description Initialization function for the deployment scripts.
 * @author      Thomas Clowes (clowes.eth)
 * @date        2025-08-22
 */

import { parseArgs, setOrDie } from "./utils.ts";
import { CHAIN_MAP } from "./constants.ts";
import 'dotenv/config'


export async function init() {

    // Get the deployment arguments
    const requiredArguments = ['chain'];
    const args: Map<string, string> = await parseArgs(requiredArguments)
        .catch(
            (e) => {
                console.error(e.message);
                process.exit();
            }
        );

    console.log('Arguments: ', args);

    let chainName;
    let chainId;
    let privateKey;

    // Loop over all known chains and see if we have a PK env variable set
    CHAIN_MAP.forEach((value, key) => {

    const pkKey = `${value.name.toUpperCase().replace('-', '_')}_PK`;
    value['privateKey'] = process.env[pkKey];

    if (value.name === args.get('chain')) {
        chainName = value.name;
        chainId = value.chain;
        privateKey = value['privateKey'];
    }
    });

    setOrDie(chainId, 'Chain ID');
    setOrDie(privateKey, 'Private Key');

    return { args, chainName, chainId, privateKey };
}
