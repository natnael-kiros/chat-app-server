import 'dart:async';
import 'package:server/group.dart';
import 'package:server/message.dart';
import 'package:server/user.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:typed_data';

class DatabaseManager {
  late Database _database;
  int _nextUserId = 1;
  final Map<String, User> _users = {};

  DatabaseManager() {
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    _database = sqlite3.open('chat_database.db');
    _database.execute(
      'CREATE TABLE IF NOT EXISTS users('
      'id INTEGER PRIMARY KEY,'
      'username TEXT UNIQUE,'
      'password TEXT,'
      'profile_image BLOB,'
      'phoneNo INTEGER)',
    );
    _database.execute(
      'CREATE TABLE IF NOT EXISTS messages('
      'messageId TEXT PRIMARY KEY, '
      'senderUsername TEXT, '
      'recipientUsername TEXT, '
      'content TEXT, '
      'timestamp TEXT, '
      'isRead INTEGER DEFAULT 0,'
      'isSent INTEGER DEFAULT 0) ',
    );
    _database.execute('CREATE TABLE IF NOT EXISTS contacts('
        'id INTEGER PRIMARY KEY, '
        'userId TEXT, '
        'username TEXT, '
        'contactPhone TEXT,'
        'FOREIGN KEY (userId) REFERENCES users(id))');
    _database.execute('CREATE TABLE IF NOT EXISTS groups('
        'groupId INTEGER PRIMARY KEY,'
        'groupname TEXT,'
        'groupowner TEXT,'
        'groupImage BLOB,'
        'created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
    _database.execute('CREATE TABLE IF NOT EXISTS group_members('
        'groupId INTEGER,'
        'userId INTEGER)');
    _database.execute('CREATE TABLE IF NOT EXISTS group_messages('
        'messageId INTEGER PRIMARY KEY AUTOINCREMENT,'
        'groupId INTEGER,'
        'groupName TEXT,'
        'senderId TEXT,'
        'senderName TEXT,'
        'messageContent TEXT,'
        'timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
  }

  Future<List<Map<String, dynamic>>> getGroupsForUser(String username) async {
    final userId = await getUserByUsername(username);

    final result = _database.select(
      'SELECT groupname FROM groups '
      'JOIN ('
      '    SELECT DISTINCT groupId FROM group_members WHERE userId = ?'
      ') AS user_groups ON groups.groupId = user_groups.groupId',
      [userId!.id],
    );

    return result.toList();
  }

  Future<void> deleteUser(String username) async {
    _database.execute('DELETE FROM users WHERE username = ?', [username]);
  }

  Future<List<String>> getAllUsernames() async {
    final result = _database.select('SELECT username FROM users');
    List<String> usernames = [];

    // Iterate over the query result and extract usernames
    for (var row in result) {
      String username = row['username'] as String;
      usernames.add(username);
    }

    return usernames;
  }

  Future<int?> getGroupIdByGroupName(String groupName) async {
    final List<Map<String, dynamic>> result = _database.select(
      'SELECT groupId FROM groups WHERE groupname = ?',
      [groupName],
    );

    if (result.isNotEmpty) {
      return result.first['groupId'] as int?;
    } else {
      // Handle the case when the group name is not found
      return null;
    }
  }

  // Assuming _database is your SQLite database instance
  Future<List<int>> getGroupMembers(String groupname) async {
    // Implement your logic to retrieve group members from the database
    // This could involve querying the group_members table based on the groupId
    // For example:
    int? groupId = await getGroupIdByGroupName(groupname);
    final List<Map<String, dynamic>> result = await _database.select(
      'SELECT userId FROM group_members WHERE groupId = ?',
      [groupId],
    );

    // Extract userIds from the result
    List<int> userIds = result.map((e) => e['userId'] as int).toSet().toList();
    print(userIds);
    return userIds;
  }

  Future<List<String>> getGroupNamesForUser(String username) async {
    print(username);
    try {
      final userId = await getUserByUsername(username);

      final List<Map<String, dynamic>> results = await _database.select('''
      SELECT DISTINCT g.groupname
      FROM groups g
      INNER JOIN group_members gm ON g.groupId = gm.groupId
      WHERE gm.userId = ?
    ''', [userId!.id]);
      print(results);
      return results.map((result) => result['groupname'] as String).toList();
    } catch (e) {
      print('Error fetching group names for user: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllGroupMessagesForUser(
      int userId) async {
    final result = _database.select(
      'SELECT * FROM group_messages WHERE groupId IN (SELECT groupId FROM group_members WHERE userId = ?) ORDER BY timestamp',
      [userId],
    );

    return result;
  }

  // Method to save a group message to the database
  Future<void> saveGroupMessage(GroupMessage message) async {
    _database.execute(
      'INSERT INTO group_messages (messageId, groupId, groupName, senderId, senderName, messageContent, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        message.messageId,
        message.groupId,
        message.groupName,
        message.senderId,
        message.senderName,
        message.messageContent,
        message.timestamp
      ],
    );
  }

  Future<void> deleteMessage(String messageId) async {
    print("Attempting to delete message with ID: $messageId");
    _database.execute('DELETE FROM messages WHERE messageId = ?', [messageId]);
    print("Message with ID: $messageId deleted.");
  }

  Future<List<Map<String, dynamic>>> getLatestMessages() async {
    final List<Map<String, dynamic>> latestMessages = _database.select('''
    SELECT recipientUsername, MAX(timestamp) AS latestTimestamp
    FROM messages
    GROUP BY recipientUsername
  ''');

    return latestMessages;
  }

  Future<User?> authenticateUser(String username, String password) async {
    final result = await _database.select(
      'SELECT * FROM users WHERE username = ? AND password = ?',
      [username, password],
    );
    if (result.isNotEmpty) {
      final userRow = result.first;
      return User(
        userRow['id'] as int,
        userRow['username'] as String,
        userRow['password'] as String,
        userRow['phoneNo'] as int,
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> getGroupByName(String groupName) async {
    final result = _database.select(
      'SELECT * FROM groups WHERE groupname = ?',
      [groupName],
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  Future<User?> getUserByUsername(String username) async {
    final result = _database.select(
      'SELECT * FROM users WHERE username = ?',
      [username],
    );
    if (result.isNotEmpty) {
      final userRow = result.first;
      // Fetch profile image data if available
      final profileImageBlob = userRow['profile_image'] as Uint8List?;
      return User(
        userRow['id'] as int,
        userRow['username'] as String,
        userRow['password'] as String,
        userRow['phoneNo'] as int,
        profileImage:
            profileImageBlob, // Pass profile image data to User constructor
      );
    }
    return null;
  }

  Future<void> updateMessageReadStatus(String username, contactUsername) async {
    try {
      _database.execute(
        'UPDATE messages SET isRead = ? WHERE recipientUsername = ? and senderUsername = ?',
        [1, username, contactUsername],
      );
      print('Message with ID $username updated: isRead = true');
    } catch (e) {
      print('Error updating message read status: $e');
      throw Exception('Error updating message read status: $e');
    }
  }

  Future<void> updateMessageSentStatus(String messageId) async {
    try {
      _database.execute(
          'UPDATE messages SET isSent = 1 WHERE messageId = ?', [messageId]);
    } catch (e) {
      print('error updating isSent');
    }
  }

  Future<bool> checkMessageExists(String messageId) async {
    try {
      final result = _database.select(
        'SELECT * FROM messages WHERE messageId = ?',
        [messageId],
      );
      return result.isNotEmpty;
    } catch (e) {
      print("Error on checkMessageExists: $e");
      return false;
    }
  }

  Future<bool> handleImageUpload(String username, List<int> imageData) async {
    try {
      // Retrieve user from the database based on the provided username
      final user = await getUserByUsername(username);
      if (user != null) {
        // Update user's profile image with the provided image data
        await updateUserProfileImage(user.id, imageData); // Modify this line
        return true; // Image upload successful
      } else {
        // User not found in the database
        return false; // Image upload failed
      }
    } catch (e) {
      print('Error uploading image: $e');
      return false; // Image upload failed due to an error
    }
  }

  Future<void> updateUserProfileImage(int userId, List<int> imageData) async {
    try {
      // Execute the SQL command to update the user's profile image
      _database.execute(
        'UPDATE users SET profile_image = ? WHERE id = ?',
        [Uint8List.fromList(imageData), userId],
      );

      // Print a success message after updating the user's profile image
    } catch (e) {
      // If an error occurs during the database operation, print the error message
      print('Error updating user profile image: $e');
      throw Exception('Error updating user profile image: $e');
    }
  }

  Future<User?> registerUser(
      String username, String password, int phoneNo) async {
    _database.execute(
      'INSERT INTO users (username, password,phoneNo) VALUES (?, ?, ?)',
      [username, password, phoneNo],
    );

    final newUser = User(_nextUserId++, username, password, phoneNo);
    _users[username] = newUser;
    return newUser;
  }

  Future createGroup(String groupname, String groupowner, List<int> groupImage,
      List groupMembers) async {
    print(groupname);
    print(groupowner);
    _database.execute(
      'INSERT INTO groups (groupname, groupowner, groupImage) VALUES (?, ?, ?)',
      [groupname, groupowner, Uint8List.fromList(groupImage)],
    );
    final group = await getGroupByName(groupname);

    for (String member in groupMembers) {
      final user = await getUserByUsername(member);

      _database.execute(
        'INSERT INTO group_members (groupId, userId) VALUES (?, ?)',
        [group!['groupId'], user!.id],
      );
    }
    return true;
  }

  Future<User?> getUserById(int id) async {
    final result = _database.select(
      'SELECT * FROM users WHERE id = ?',
      [id],
    );
    if (result.isNotEmpty) {
      final userRow = result.first;
      return User(
        userRow['id'] as int,
        userRow['username'] as String,
        userRow['password'] as String,
        userRow['phoneNo'] as int,
      );
    }
    return null;
  }

  Future<void> addContact(String username, String contactUsername,
      String contactPhoneNumber) async {
    User? user = await getUserByUsername(username);
    if (user != null) {
      String userId = user.id.toString();
      _database.execute(
        'INSERT INTO contacts (userId, username, contactPhone) VALUES (?, ?,?)',
        [userId, contactUsername, contactPhoneNumber],
      );
    } else {
      // Handle the case where the user does not exist
    }
  }

  Future<List<Map<String, dynamic>>> getContacts(String username) async {
    User? user = await getUserByUsername(username);
    if (user != null) {
      String userId = user.id.toString();
      final List<Map<String, dynamic>> contacts = await _database.select(
        'SELECT * FROM contacts WHERE userId = ?',
        [userId],
      );
      return contacts;
    } else {
      print("User not found");
      // Return an empty list if the user is not found
      return [];
    }
  }

  Future<void> updateContact(int contactId, String newUsername) async {
    _database.execute(
      'UPDATE contacts SET username = ? WHERE id = ?',
      [newUsername, contactId],
    );
  }

  Future<void> deleteContact(String username, String contactUsername) async {
    User? user = await getUserByUsername(username);
    if (user != null) {
      String userId = user.id.toString();
      _database.execute(
        'DELETE FROM contacts WHERE userId = ? AND username = ?',
        [userId, contactUsername],
      );
    } else {
      // Handle the case where the user is not found
      print('User not found');
    }
  }

  void saveMessage(Message message) {
    print('Message before insertion: ${message.isRead}');
    _database.execute(
      'INSERT INTO messages (messageId, senderUsername, recipientUsername, content, timestamp,isRead,isSent) VALUES (?,?,?,?,?,?,?)',
      [
        message.messageId,
        message.senderUsername,
        message.recipientUsername,
        message.content,
        message.timestamp,
        message.isRead ? 1 : 0,
        message.isSent ? 1 : 0, // 1 means true, 0 means false
      ],
    );
    print('Message after insertion: ${message.isRead}');
    // Call debug function after insertion
  }

  List<Message> getAllMessagesForUser(String username) {
    final result = _database.select(
      'SELECT * FROM messages WHERE recipientUsername = ? OR senderUsername = ?',
      [username, username],
    );

    return result
        .map((row) => Message(
              row['messageId'] as String,
              row['senderUsername'] as String,
              row['recipientUsername'] as String,
              row['content'] as String,
              row['timestamp'] as String,
              (row['isRead'] as int) == 1,
              (row['isSent'] as int) == 1,
            ))
        .toList();
  }
}
