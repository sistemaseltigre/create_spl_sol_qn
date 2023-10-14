import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/src/metaplex/metaplex.dart' as metaplex;

Future<String> createToken(
    solana.SolanaClient client,
    String name,
    String symbol,
    String description,
    int decimals,
    int initialMint,
    String uri) async {
  final storage = FlutterSecureStorage();

  final mainWalletKey = await storage.read(key: 'mnemonic');

  final mainWalletSolana = await solana.Ed25519HDKeyPair.fromMnemonic(
    mainWalletKey!,
  );

  final mint = await client.initializeMint(
      mintAuthority: mainWalletSolana,
      freezeAuthority: mainWalletSolana.publicKey,
      decimals: decimals,
      commitment: solana.Commitment.confirmed);

  final ata = await client.createAssociatedTokenAccount(
    mint: mint.address,
    funder: mainWalletSolana,
    commitment: solana.Commitment.confirmed,
  );

  final ataPK = solana.Ed25519HDPublicKey.fromBase58(ata.pubkey);

  await client.mintTo(
      mint: mint.address,
      destination: ataPK,
      amount: initialMint,
      authority: mainWalletSolana,
      commitment: solana.Commitment.confirmed);

  final data = metaplex.CreateMetadataAccountV3Data(
    name: name,
    symbol: symbol,
    uri: uri,
    sellerFeeBasisPoints: 0,
    isMutable: false,
    colectionDetails: false,
  );
  inspect(data);

  final instruction = await metaplex.createMetadataAccountV3(
    mint: mint.address,
    mintAuthority: mainWalletSolana.publicKey,
    payer: mainWalletSolana.publicKey,
    updateAuthority: mainWalletSolana.publicKey,
    data: data,
  );

  final message = solana.Message.only(instruction);

  final result = await client.sendAndConfirmTransaction(
    message: message,
    signers: [mainWalletSolana],
    commitment: solana.Commitment.confirmed,
  );

  return result;
}
