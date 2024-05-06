import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:image_picker/image_picker.dart'; // Import de la bibliothèque image_picker
import 'dart:io';

void main() => runApp(MyApp());

class Food {
  int? id;
  String? name;
  String? image;
  double? price;
  int? stars;
  String? description;

  Food(
      {this.id,
      this.name,
      this.image,
      this.price,
      this.stars,
      this.description});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'price': price,
      'stars': stars,
      'description': description,
    };
  }

  static Food fromMap(Map<String, dynamic> map) {
    return Food(
      id: map['id'],
      name: map['name'],
      image: map['image'],
      price: map['price'],
      stars: map['stars'],
      description: map['description'],
    );
  }
}

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await initDatabase();
    return _database!;
  }

  static Future<Database> initDatabase() async {
    final path = await getDatabasesPath();
    return openDatabase(
      join(path, 'food_database.db'),
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE foods(id INTEGER PRIMARY KEY, name TEXT, image TEXT, price REAL, stars INTEGER, description TEXT)",
        );
      },
      version: 1,
    );
  }

  static Future<void> insertFood(Food food) async {
    final db = await database;
    await db.insert('foods', food.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Food>> getFoods() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('foods');
    return List.generate(maps.length, (i) {
      return Food.fromMap(maps[i]);
    });
  }

  static Future<void> updateFood(Food food) async {
    final db = await database;
    await db.update(
      'foods',
      food.toMap(),
      where: 'id = ?',
      whereArgs: [food.id],
    );
  }

  static Future<void> deleteFood(int id) async {
    final db = await database;
    await db.delete(
      'foods',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.brown, // Couleur d'en-tête personnalisée
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Database _database;
  List<Food> _foodList = [];

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  Future<void> _openDatabase() async {
    try {
      _database = await openDatabase(
        join(await getDatabasesPath(), 'food_database.db'),
        onCreate: (db, version) {
          return db.execute(
            "CREATE TABLE foods(id INTEGER PRIMARY KEY, name TEXT, image TEXT, price REAL, stars INTEGER, description TEXT)",
          );
        },
        version: 1,
      );
      _refreshList();
    } catch (e) {
      print("Erreur lors de l'ouverture de la base de données: $e");
    }
  }

  Future<void> _refreshList() async {
    final List<Map<String, dynamic>> foods = await _database.query('foods');
    setState(() {
      _foodList = foods.map((food) => Food.fromMap(food)).toList();
    });
  }

  Future<void> _addFood(BuildContext context) async {
    TextEditingController nameController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();

    XFile? imageFile;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        double stars = 0;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Ajouter un aliment'),
              content: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Nom'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setState(() {
                            imageFile = pickedFile;
                          });
                        }
                      },
                      child: Text('Sélectionner une image'),
                    ),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(labelText: 'Prix'),
                      keyboardType: TextInputType.number,
                    ),
                    Row(
                      children: <Widget>[
                        Text('Rating: ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Slider(
                            value: stars,
                            min: 0,
                            max: 5,
                            divisions: 5,
                            onChanged: (newValue) {
                              setState(() {
                                stars = newValue;
                              });
                            },
                          ),
                        ),
                        Text(stars.toStringAsFixed(1),
                            style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(labelText: 'Description'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String name = nameController.text;
                    double price = double.tryParse(priceController.text) ?? 0.0;
                    String description = descriptionController.text;

                    // Vérifier si une image a été sélectionnée
                    if (imageFile != null) {
                      // Enregistrer l'image dans le répertoire temporaire de l'application
                      String imagePath = imageFile!.path;
                      await DatabaseHelper.insertFood(
                        Food(
                            name: name,
                            image: imagePath,
                            price: price,
                            stars: stars.toInt(),
                            description: description),
                      );

                      _refreshList();
                    }

                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Ajouter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteFood(int id) async {
    await DatabaseHelper.deleteFood(id);
    _refreshList();
  }

  Future<void> _editFood(BuildContext context, Food food) async {
    TextEditingController nameController =
        TextEditingController(text: food.name);
    TextEditingController priceController =
        TextEditingController(text: food.price.toString());
    TextEditingController descriptionController =
        TextEditingController(text: food.description);

    XFile? imageFile = XFile(food.image!);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        double stars = food.stars?.toDouble() ?? 0;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Modifier un aliment'),
              content: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Nom'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setState(() {
                            imageFile = pickedFile;
                          });
                        }
                      },
                      child: Text('Sélectionner une image'),
                    ),
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(labelText: 'Prix'),
                    ),
                    Row(
                      children: <Widget>[
                        Text('Rating: ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Slider(
                            value: stars,
                            min: 0,
                            max: 5,
                            divisions: 5,
                            onChanged: (newValue) {
                              setState(() {
                                stars = newValue;
                              });
                            },
                          ),
                        ),
                        Text(stars.toStringAsFixed(1),
                            style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(labelText: 'Description'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String name = nameController.text;
                    double price = double.tryParse(priceController.text) ?? 0.0;
                    String description = descriptionController.text;

                    // Vérifier si une nouvelle image a été sélectionnée
                    if (imageFile != null) {
                      // Enregistrer la nouvelle image dans le répertoire temporaire de l'application
                      String newImagePath = imageFile!.path;
                      Food updatedFood = Food(
                        id: food.id,
                        name: name,
                        image: newImagePath,
                        price: price,
                        stars: stars.toInt(),
                        description: description,
                      );

                      await DatabaseHelper.updateFood(updatedFood);
                      _refreshList();
                    }

                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Food App', style: TextStyle(color: Colors.white)),
      ),
      body: ListView.builder(
        itemCount: (_foodList.length / 2)
            .ceil(), // Utiliser la moitié du nombre d'éléments pour définir le nombre de lignes
        itemBuilder: (context, rowIndex) {
          return Row(
            children: [
              Expanded(
                child: buildCard(context,
                    rowIndex * 2), // Afficher la carte pour l'élément de gauche
              ),
              SizedBox(width: 8), // Espacement entre les cartes
              Expanded(
                child: (rowIndex * 2 + 1 < _foodList.length)
                    ? buildCard(
                        context,
                        rowIndex * 2 +
                            1) // Afficher la carte pour l'élément de droite si disponible
                    : Container(), // Sinon, afficher un conteneur vide
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _addFood(context);
        },
        tooltip: 'Ajouter',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget buildCard(BuildContext context, int index) {
    final food = _foodList[index];
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (food.image != null)
                    Image.file(File(food.image!),
                        width: 200, height: 200, fit: BoxFit.cover),
                  SizedBox(height: 8),
                  Text('Nom: ${food.name ?? ''}',
                      style: TextStyle(fontSize: 16)),
                  Text('Prix: \$${food.price?.toStringAsFixed(2) ?? ''}',
                      style: TextStyle(fontSize: 16)),
                  Row(
                    children: [
                      Text('Rating: ', style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Slider(
                          value: food.stars?.toDouble() ?? 0,
                          min: 0,
                          max: 5,
                          divisions: 5,
                          onChanged: (newValue) {
                            setState(() {
                              food.stars = newValue.toInt();
                            });
                          },
                        ),
                      ),
                      Text((food.stars ?? 0).toString(),
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  Text('Description: ${food.description ?? ''}',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Fermer'),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _editFood(context, food);
                  },
                  icon: Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteFood(food.id!);
                  },
                  icon: Icon(Icons.delete),
                ),
              ],
            );
          },
        );
      },
      child: Card(
        elevation: 4,
        margin: EdgeInsets.all(8),
        color: Colors.brown, // Couleur de fond orange

        child: Container(
          width: double.infinity, // Utiliser toute la largeur disponible
          height: 290, // Hauteur fixe de la carte
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.brown, width: 4), // Bordure de couleur orange
            borderRadius: BorderRadius.circular(8), // Coins arrondis
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1, // Ratio d'aspect 1:1 pour maintenir un carré
                child: food.image != null
                    ? Image.file(File(food.image!), fit: BoxFit.cover)
                    : Icon(Icons.image, size: 80),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name ?? '', style: TextStyle(fontSize: 16)),
                    Text('\$${food.price?.toStringAsFixed(2) ?? ''}',
                        style: TextStyle(fontSize: 16)),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < (food.stars ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.yellow,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:path/path.dart';
// import 'package:image_picker/image_picker.dart'; // Import de la bibliothèque image_picker
// import 'dart:io';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// // import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

// void main() async {
//   await DatabaseHelper.initDatabase();
//   runApp(MyApp());
// }

// class Food {
//   int? id;
//   String? name;
//   String? image;
//   double? price;
//   int? stars;
//   String? description;

//   Food(
//       {this.id,
//       this.name,
//       this.image,
//       this.price,
//       this.stars,
//       this.description});

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'image': image,
//       'price': price,
//       'stars': stars,
//       'description': description,
//     };
//   }

//   static Food fromMap(Map<String, dynamic> map) {
//     return Food(
//       id: map['id'],
//       name: map['name'],
//       image: map['image'],
//       price: map['price'],
//       stars: map['stars'],
//       description: map['description'],
//     );
//   }
// }

// class DatabaseHelper {
//   static Database? _database;

//   static Future<Database> get database async {
//     if (_database != null) {
//       return _database!;
//     }

//     _database = await initDatabase();
//     return _database!;
//   }

//   static Future<Database> initDatabase() async {
//     // databaseFactoryOrNull = null;
//     // sqfliteFfiInit();
//     databaseFactory = databaseFactoryFfi;

//     final path = await getDatabasesPath();
//     print(path);
//     return openDatabase(
//       join(path, 'food_database.db'),
//       onCreate: (db, version) {
//         return db.execute(
//           "CREATE TABLE foods(id INTEGER PRIMARY KEY, name TEXT, image TEXT, price REAL, stars INTEGER, description TEXT)",
//         );
//       },
//       version: 1,
//     );
//   }

//   static Future<void> insertFood(Food food) async {
//     final db = await database;
//     await db.insert('foods', food.toMap(),
//         conflictAlgorithm: ConflictAlgorithm.replace);
//   }

//   static Future<List<Food>> getFoods() async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps = await db.query('foods');
//     return List.generate(maps.length, (i) {
//       return Food.fromMap(maps[i]);
//     });
//   }

//   static Future<void> updateFood(Food food) async {
//     final db = await database;
//     await db.update(
//       'foods',
//       food.toMap(),
//       where: 'id = ?',
//       whereArgs: [food.id],
//     );
//   }

//   static Future<void> deleteFood(int id) async {
//     final db = await database;
//     await db.delete(
//       'foods',
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//   }
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         appBarTheme: AppBarTheme(
//           backgroundColor: Colors.orange, // Couleur d'en-tête personnalisée
//         ),
//       ),
//       home: HomePage(),
//     );
//   }
// }

// class HomePage extends StatefulWidget {
//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   late Database _database;
//   List<Food> _foodList = [];

//   @override
//   void initState() {
//     super.initState();
//     _openDatabase();
//   }

//   Future<void> _openDatabase() async {
//     try {
//       _database = await openDatabase(
//         join(await getDatabasesPath(), 'food_database.db'),
//         onCreate: (db, version) {
//           return db.execute(
//             "CREATE TABLE foods(id INTEGER PRIMARY KEY, name TEXT, image TEXT, price REAL, stars INTEGER, description TEXT)",
//           );
//         },
//         version: 1,
//       );
//       _refreshList();
//     } catch (e) {
//       print("Erreur lors de l'ouverture de la base de données: $e");
//     }
//   }

//   Future<void> _refreshList() async {
//     final List<Map<String, dynamic>> foods = await _database.query('foods');
//     setState(() {
//       _foodList = foods.map((food) => Food.fromMap(food)).toList();
//     });
//   }

//   Future<void> _addFood(BuildContext context) async {
//     TextEditingController nameController = TextEditingController();
//     TextEditingController priceController = TextEditingController();
//     TextEditingController descriptionController = TextEditingController();

//     XFile? imageFile;

//     await showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         double stars = 0;
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Ajouter un aliment'),
//               content: SingleChildScrollView(
//                 child: Column(
//                   children: <Widget>[
//                     TextField(
//                       controller: nameController,
//                       decoration: InputDecoration(labelText: 'Nom'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () async {
//                         final picker = ImagePicker();
//                         final pickedFile =
//                             await picker.pickImage(source: ImageSource.gallery);
//                         if (pickedFile != null) {
//                           setState(() {
//                             imageFile = pickedFile;
//                           });
//                         }
//                       },
//                       child: Text('Sélectionner une image'),
//                     ),
//                     TextField(
//                       controller: priceController,
//                       decoration: InputDecoration(labelText: 'Prix'),
//                       keyboardType: TextInputType.number,
//                     ),
//                     Row(
//                       children: <Widget>[
//                         Text('Rating: ', style: TextStyle(fontSize: 16)),
//                         Expanded(
//                           child: Slider(
//                             value: stars,
//                             min: 0,
//                             max: 5,
//                             divisions: 5,
//                             onChanged: (newValue) {
//                               setState(() {
//                                 stars = newValue;
//                               });
//                             },
//                           ),
//                         ),
//                         Text(stars.toStringAsFixed(1),
//                             style: TextStyle(fontSize: 16)),
//                       ],
//                     ),
//                     TextField(
//                       controller: descriptionController,
//                       decoration: InputDecoration(labelText: 'Description'),
//                     ),
//                   ],
//                 ),
//               ),
//               actions: <Widget>[
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(dialogContext).pop();
//                   },
//                   child: Text('Annuler'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () async {
//                     String name = nameController.text;
//                     double price = double.tryParse(priceController.text) ?? 0.0;
//                     String description = descriptionController.text;

//                     // Vérifier si une image a été sélectionnée
//                     if (imageFile != null) {
//                       // Enregistrer l'image dans le répertoire temporaire de l'application
//                       String imagePath = imageFile!.path;
//                       await DatabaseHelper.insertFood(
//                         Food(
//                             name: name,
//                             image: imagePath,
//                             price: price,
//                             stars: stars.toInt(),
//                             description: description),
//                       );

//                       _refreshList();
//                     }

//                     Navigator.of(dialogContext).pop();
//                   },
//                   child: Text('Ajouter'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Future<void> _deleteFood(int id) async {
//     await DatabaseHelper.deleteFood(id);
//     _refreshList();
//   }

//   Future<void> _editFood(BuildContext context, Food food) async {
//     TextEditingController nameController =
//         TextEditingController(text: food.name);
//     TextEditingController priceController =
//         TextEditingController(text: food.price.toString());
//     TextEditingController descriptionController =
//         TextEditingController(text: food.description);

//     XFile? imageFile = XFile(food.image!);

//     await showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         double stars = food.stars?.toDouble() ?? 0;
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Modifier un aliment'),
//               content: SingleChildScrollView(
//                 child: Column(
//                   children: <Widget>[
//                     TextField(
//                       controller: nameController,
//                       decoration: InputDecoration(labelText: 'Nom'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () async {
//                         final picker = ImagePicker();
//                         final pickedFile =
//                             await picker.pickImage(source: ImageSource.gallery);
//                         if (pickedFile != null) {
//                           setState(() {
//                             imageFile = pickedFile;
//                           });
//                         }
//                       },
//                       child: Text('Sélectionner une image'),
//                     ),
//                     TextField(
//                       controller: priceController,
//                       decoration: InputDecoration(labelText: 'Prix'),
//                     ),
//                     Row(
//                       children: <Widget>[
//                         Text('Rating: ', style: TextStyle(fontSize: 16)),
//                         Expanded(
//                           child: Slider(
//                             value: stars,
//                             min: 0,
//                             max: 5,
//                             divisions: 5,
//                             onChanged: (newValue) {
//                               setState(() {
//                                 stars = newValue;
//                               });
//                             },
//                           ),
//                         ),
//                         Text(stars.toStringAsFixed(1),
//                             style: TextStyle(fontSize: 16)),
//                       ],
//                     ),
//                     TextField(
//                       controller: descriptionController,
//                       decoration: InputDecoration(labelText: 'Description'),
//                     ),
//                   ],
//                 ),
//               ),
//               actions: <Widget>[
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(dialogContext).pop();
//                   },
//                   child: Text('Annuler'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () async {
//                     String name = nameController.text;
//                     double price = double.tryParse(priceController.text) ?? 0.0;
//                     String description = descriptionController.text;

//                     // Vérifier si une nouvelle image a été sélectionnée
//                     if (imageFile != null) {
//                       // Enregistrer la nouvelle image dans le répertoire temporaire de l'application
//                       String newImagePath = imageFile!.path;
//                       Food updatedFood = Food(
//                         id: food.id,
//                         name: name,
//                         image: newImagePath,
//                         price: price,
//                         stars: stars.toInt(),
//                         description: description,
//                       );

//                       await DatabaseHelper.updateFood(updatedFood);
//                       _refreshList();
//                     }

//                     Navigator.of(dialogContext).pop();
//                   },
//                   child: Text('Enregistrer'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Food App', style: TextStyle(color: Colors.white)),
//       ),
//       body: ListView.builder(
//         itemCount: (_foodList.length / 2)
//             .ceil(), // Utiliser la moitié du nombre d'éléments pour définir le nombre de lignes
//         itemBuilder: (context, rowIndex) {
//           return Row(
//             children: [
//               Expanded(
//                 child: buildCard(context,
//                     rowIndex * 2), // Afficher la carte pour l'élément de gauche
//               ),
//               SizedBox(width: 8), // Espacement entre les cartes
//               Expanded(
//                 child: (rowIndex * 2 + 1 < _foodList.length)
//                     ? buildCard(
//                         context,
//                         rowIndex * 2 +
//                             1) // Afficher la carte pour l'élément de droite si disponible
//                     : Container(), // Sinon, afficher un conteneur vide
//               ),
//             ],
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           _addFood(context);
//         },
//         tooltip: 'Ajouter',
//         child: Icon(Icons.add),
//       ),
//     );
//   }

//   Widget buildCard(BuildContext context, int index) {
//     final food = _foodList[index];
//     return GestureDetector(
//       onTap: () {
//         showDialog(
//           context: context,
//           builder: (BuildContext context) {
//             return AlertDialog(
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (food.image != null)
//                     Image.file(File(food.image!),
//                         width: 200, height: 200, fit: BoxFit.cover),
//                   SizedBox(height: 8),
//                   Text('Nom: ${food.name ?? ''}',
//                       style: TextStyle(fontSize: 16)),
//                   Text('Prix: \$${food.price?.toStringAsFixed(2) ?? ''}',
//                       style: TextStyle(fontSize: 16)),
//                   Row(
//                     children: [
//                       Text('Rating: ', style: TextStyle(fontSize: 16)),
//                       Expanded(
//                         child: Slider(
//                           value: food.stars?.toDouble() ?? 0,
//                           min: 0,
//                           max: 5,
//                           divisions: 5,
//                           onChanged: (newValue) {
//                             setState(() {
//                               food.stars = newValue.toInt();
//                             });
//                           },
//                         ),
//                       ),
//                       Text((food.stars ?? 0).toString(),
//                           style: TextStyle(fontSize: 16)),
//                     ],
//                   ),
//                   Text('Description: ${food.description ?? ''}',
//                       style: TextStyle(fontSize: 16)),
//                 ],
//               ),
//               actions: [
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                   },
//                   child: Text('Fermer'),
//                 ),
//                 IconButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     _editFood(context, food);
//                   },
//                   icon: Icon(Icons.edit),
//                 ),
//                 IconButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     _deleteFood(food.id!);
//                   },
//                   icon: Icon(Icons.delete),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//       child: Card(
//         elevation: 4,
//         margin: EdgeInsets.all(8),
//         color: Colors.orange, // Couleur de fond orange

//         child: Container(
//           width: double.infinity, // Utiliser toute la largeur disponible
//           height: 290, // Hauteur fixe de la carte
//           decoration: BoxDecoration(
//             border: Border.all(
//                 color: Colors.orange, width: 4), // Bordure de couleur orange
//             borderRadius: BorderRadius.circular(8), // Coins arrondis
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               AspectRatio(
//                 aspectRatio: 1, // Ratio d'aspect 1:1 pour maintenir un carré
//                 child: food.image != null
//                     ? Image.file(File(food.image!), fit: BoxFit.cover)
//                     : Icon(Icons.image, size: 80),
//               ),
//               Padding(
//                 padding: EdgeInsets.all(8),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(food.name ?? '', style: TextStyle(fontSize: 16)),
//                     Text('\$${food.price?.toStringAsFixed(2) ?? ''}',
//                         style: TextStyle(fontSize: 16)),
//                     Row(
//                       children: List.generate(5, (index) {
//                         return Icon(
//                           index < (food.stars ?? 0)
//                               ? Icons.star
//                               : Icons.star_border,
//                           color: Colors.yellow,
//                         );
//                       }),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
