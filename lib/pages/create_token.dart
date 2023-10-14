import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:solana/solana.dart';

import '../services/mint_nft.dart';
import '../services/token_create.dart';
import '../services/upload_to_ipfs.dart';

class CreateTokenPage extends StatefulWidget {
  final SolanaClient client;
  const CreateTokenPage({super.key, required this.client});

  @override
  State<CreateTokenPage> createState() => _CreateTokenPageState();
}

class _CreateTokenPageState extends State<CreateTokenPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  File? _imageFile;

  final nameController = TextEditingController();
  final symbolController = TextEditingController();
  final descriptionController = TextEditingController();
  final decimalsController = TextEditingController();
  final initialMintController = TextEditingController();

  bool _uploadingImage = false;
  bool _imageUploaded = false;
  bool _uploadingJson = false;
  bool _jsonUploaded = false;
  bool _creatingToken = false;
  bool _tokenCreated = false;
  String imageUrl = "";
  String cid = "";
  String createTokenResult = "";

  void _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  _uploadImage() async {
    final uploadImageResult = await uploadToIPFS(_imageFile!);

    if (uploadImageResult != null) {
      imageUrl = uploadImageResult;
      setState(() {
        _imageUploaded = true;
        _uploadingJson = true;
      });
      _uploadJson();
    }
  }

  _uploadJson() async {
    Map<String, dynamic> data = {
      'name': nameController.text,
      'symbol': symbolController.text,
      'description': descriptionController.text,
      'image': 'https://quicknode.myfilebase.com/ipfs/$imageUrl',
    };

    String json = jsonEncode(data);

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${nameController.text}.json');
    await file.writeAsString(json);

    final uploadJsonResult = await uploadToIPFS(file);

    if (uploadJsonResult != null) {
      cid = uploadJsonResult;

      setState(() {
        _jsonUploaded = true;
        _creatingToken = true;
      });
      _createToken();
    }
  }

  _createToken() async {
    int decimals = int.parse(decimalsController.text);
    int initialMint = int.parse(initialMintController.text);
    num amount = initialMint * pow(10, decimals);
    int mintAmount = int.parse(amount.toString());
    String uri = "https://quicknode.myfilebase.com/ipfs/$cid/";
    createTokenResult = await createToken(
        widget.client,
        nameController.text,
        symbolController.text,
        descriptionController.text,
        decimals,
        mintAmount,
        uri);

    setState(() {
      _tokenCreated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Create Token')),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            GoRouter.of(context).go("/home");
          },
          backgroundColor: Colors.white.withOpacity(0.3),
          child: const Icon(
            Icons.arrow_back,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(children: [
              SizedBox(
                width: 200,
                height: 200,
                child: _imageFile != null
                    ? Image.file(_imageFile!)
                    : const Placeholder(),
              ),
              TextButton(
                  onPressed: _pickImage, child: const Text('Choose Image')),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: symbolController,
                decoration: const InputDecoration(labelText: 'Symbol'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a symbol';
                  }
                  return null;
                },
              ),
              TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  }),
              TextFormField(
                  controller: decimalsController,
                  decoration: const InputDecoration(labelText: 'Decimals'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter number of Decimals';
                    }
                    return null;
                  }),
              TextFormField(
                  controller: initialMintController,
                  decoration: const InputDecoration(labelText: 'initialMint'),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter the initial Mint';
                    }
                    return null;
                  }),
              ElevatedButton(
                onPressed: () {
                  if (!_tokenCreated) {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    setState(() {
                      _uploadingImage = true;
                    });
                    _uploadImage();
                  } else {
                    GoRouter.of(context).go("/home");
                  }
                },
                child: _tokenCreated
                    ? const Text('Accept')
                    : const Text('Create token'),
              ),
              if (_uploadingImage)
                _imageUploaded
                    ? const Row(
                        children: [
                          Icon(Icons.check, color: Colors.green),
                          Text("Image Uploaded")
                        ],
                      )
                    : const Row(
                        children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator()),
                          Text("Uploading Images")
                        ],
                      ),
              if (_uploadingJson)
                _jsonUploaded
                    ? const Row(
                        children: [
                          Icon(Icons.check, color: Colors.green),
                          Text("json Uploaded")
                        ],
                      )
                    : const Row(
                        children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator()),
                          Text("Uploading Json")
                        ],
                      ),
              if (_creatingToken)
                _tokenCreated
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          Icon(Icons.check, color: Colors.green),
                          Text(createTokenResult)
                        ]),
                      )
                    : const Row(
                        children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator()),
                          Text("Creating Token...")
                        ],
                      )
            ]),
          ),
        ));
  }
}
