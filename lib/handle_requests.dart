import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:server/database.dart';
import 'package:server/message.dart';
import 'package:server/user.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart' as shelf_web_socket;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:typed_data';

class HandleRequest {
  late DatabaseManager _databaseManager;

  HandleRequest() {
    _databaseManager = DatabaseManager();
  }
  // Future<shelf.Response> handleGetGroupMessages(shelf.Request request) async {
  //   try {
  //     // Extract group ID from the request URL
  //     final groupId = int.tryParse(request.url.pathSegments.last);
  //     if (groupId == null) {
  //       return shelf.Response.badRequest();
  //     }

  //     // Fetch messages for the specified group from the database
  //     final messages =
  //         await _databaseManager.getAllGroupMessagesForUser(groupId);

  //     // Serialize messages to JSON and return as response
  //     return shelf.Response.ok(json.encode(messages),
  //         headers: {'Content-Type': 'application/json'});
  //   } catch (e) {
  //     print('Error fetching group messages: $e');
  //     return shelf.Response.internalServerError();
  //   }
  // }

  Future<shelf.Response> handleGetUserGroups(shelf.Request request) async {
    try {
      // Extract username from the request URL
      final username = request.url.pathSegments.last;
      if (username.isEmpty) {
        return shelf.Response.badRequest();
      }

      // Fetch groups for the specified user from the database
      final userGroups = await _databaseManager.getGroupsForUser(username);

      // Serialize groups to JSON and return as response
      return shelf.Response.ok(json.encode(userGroups),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('Error fetching user groups: $e');
      return shelf.Response.internalServerError();
    }
  }

  // Future<shelf.Response> handleSendGroupMessage(shelf.Request request) async {
  //   try {
  //     // Read request body as JSON
  //     final requestBody = await request.readAsString();
  //     final messageData = json.decode(requestBody);

  //     // Extract message details from the request body
  //     final groupId = messageData['group_id'];
  //     final senderId = messageData['sender_id'];
  //     final messageContent = messageData['message_content'];

  //     // Validate message data
  //     if (groupId == null || senderId == null || messageContent == null) {
  //       return shelf.Response.badRequest();
  //     }

  //     // Save the message to the database
  //     await _databaseManager.saveGroupMessage(
  //         groupId, senderId, messageContent);

  //     // Return success response
  //     return shelf.Response.ok('Message sent successfully');
  //   } catch (e) {
  //     print('Error sending group message: $e');
  //     return shelf.Response.internalServerError();
  //   }
  // }

  Future<shelf.Response> handleLoginRequest(shelf.Request request) async {
    final requestBody = await request.readAsString();
    final Map<String, dynamic> userData = jsonDecode(requestBody);

    final String username = userData['username'];
    final String password = userData['password'];

    final user = await _databaseManager.authenticateUser(username, password);
    if (user != null) {
      final responseData = {
        'userId': user.id,
        'username': user.username,
        'phoneNo': user.phoneNo,
      };

      // Debug: Print data types of response
      print('Type of userId: ${responseData['userId'].runtimeType}');
      print('Type of username: ${responseData['username'].runtimeType}');
      print('Type of phoneNo: ${responseData['phoneNo'].runtimeType}');

      return shelf.Response.ok(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    } else {
      return shelf.Response.forbidden('Invalid username or password');
    }
  }

  Future<shelf.Response> handleRegisterRequest(shelf.Request request) async {
    final requestBody = await request.readAsString();
    final Map<String, dynamic> userData = jsonDecode(requestBody);

    final String username = userData['username'];
    final String password = userData['password'];
    final int phoneNo = userData['phoneNo'];

    final newUser =
        await _databaseManager.registerUser(username, password, phoneNo);
    if (newUser != null) {
      return shelf.Response.ok(jsonEncode(newUser.toJson()),
          headers: {'Content-Type': 'application/json'});
    } else {
      return shelf.Response(409,
          body: 'User already exists', headers: {'Content-Type': 'text/plain'});
    }
  }

  Future<void> handleUpdateMessageRequest(shelf.Request request) async {
    final requestBody = await request.readAsString();
    final Map<String, dynamic> messageData = jsonDecode(requestBody);

    final contactUsername = messageData['contactUsername'];
    final username = messageData['username'];

    _databaseManager.updateMessageReadStatus(username, contactUsername);
  }

  Future<shelf.Response> handleAddContactRequest(shelf.Request request) async {
    try {
      final requestBody = await request.readAsString();
      final Map<String, dynamic> contactData = jsonDecode(requestBody);

      print(contactData['userId']);

      final String username = contactData['username'];
      final String contactUsername = contactData['contactUsername'];
      final String contactPhone = contactData['contactPhone'];

      // Add the contact to the database
      await _databaseManager.addContact(
          username, contactUsername, contactPhone);

      return shelf.Response.ok('Contact added successfully');
    } catch (e) {
      print('Error adding contact: $e');
      return shelf.Response.internalServerError();
    }
  }

  Future<shelf.Response> handleGetContactsRequest(shelf.Request request) async {
    try {
      final requestBody = await request.readAsString();
      final Map<String, dynamic> requestData = jsonDecode(requestBody);
      final String username = requestData['username'];

      // Retrieve contacts for the given username
      final List<Map<String, dynamic>> contacts =
          await _databaseManager.getContacts(username);

      return shelf.Response.ok(jsonEncode(contacts),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('Error retrieving contacts: $e');
      return shelf.Response.internalServerError();
    }
  }

  Future<shelf.Response> handleTimeRequest(shelf.Request request) async {
    var currentTime = DateTime.now().toIso8601String();
    return shelf.Response.ok(jsonEncode({'time': currentTime}),
        headers: {'Content-Type': 'application/json'});
  }

  Future<shelf.Response> handleUpdateContactRequest(
      shelf.Request request) async {
    try {
      final requestBody = await request.readAsString();
      final Map<String, dynamic> contactData = jsonDecode(requestBody);

      final int contactId = contactData['id'];
      final String newUsername = contactData['newUsername'];

      // Update the contact in the database
      await _databaseManager.updateContact(contactId, newUsername);

      return shelf.Response.ok('Contact updated successfully');
    } catch (e) {
      print('Error updating contact: $e');
      return shelf.Response.internalServerError();
    }
  }

  Future<shelf.Response> handleRemoveContactRequest(
      shelf.Request request) async {
    try {
      final requestBody = await request.readAsString();
      final Map<String, dynamic> contactData = jsonDecode(requestBody);

      final String username = contactData['username'];
      final String contactUsername = contactData['contactUsername'];

      // Delete the contact from the database
      await _databaseManager.deleteContact(username, contactUsername);

      return shelf.Response.ok('Contact deleted successfully');
    } catch (e) {
      print('Error deleting contact: $e');
      return shelf.Response.internalServerError();
    }
  }

  Future<shelf.Response> handleCreateGroupRequest(shelf.Request request) async {
    try {
      final requestBody = await request.readAsString();
      final Map<String, dynamic> groupData = jsonDecode(requestBody);

      final String groupname = groupData['groupname'];
      final String groupowner = groupData['groupowner'];
      final String groupImage = groupData['groupImage'];
      final List groupMembers = groupData['groupMembers'];
      final List<int> imageBytes = base64Decode(groupImage);

      await _databaseManager.createGroup(
          groupname, groupowner, imageBytes, groupMembers);
      return shelf.Response.ok("Group Created Successfuly");
    } catch (e) {
      print('Error creating group: $e');
      return shelf.Response.internalServerError();
    }
  }

  Future<shelf.Response> handleUploadImageRequest(shelf.Request request) async {
    // Read request body as JSON
    String requestBody = await request.readAsString();

    // Decode JSON body
    Map<String, dynamic> body = jsonDecode(requestBody);
    String username = body['username'];
    String imageBase64 = body['image'];

    // Decode image base64 string
    List<int> imageBytes = base64Decode(imageBase64);

    // Call the function to handle image upload and username processing
    bool success =
        await _databaseManager.handleImageUpload(username, imageBytes);

    if (success) {
      // Return a success response if image upload was successful
      return shelf.Response.ok('Image uploaded successfully');
    } else {
      // Return an error response if image upload failed
      return shelf.Response.internalServerError();
    }
  }

  Future<shelf.Response> handleGetLatestMessagesRequest(
      shelf.Request request) async {
    try {
      final latestMessages = await _databaseManager.getLatestMessages();
      final responseBody = jsonEncode(latestMessages);
      return shelf.Response.ok(responseBody,
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return shelf.Response.internalServerError(
          body: 'Error fetching latest messages: $e');
    }
  }

  Future<shelf.Response> handleGetUserExistsRequest(
      shelf.Request request) async {
    final username = request.url.pathSegments[1];
    final user = await _databaseManager.getUserByUsername(username);
    if (user != null) {
      return shelf.Response.ok(jsonEncode(user.toJson()),
          headers: {'Content-Type': 'application/json'});
    } else {
      return shelf.Response.notFound('User not found');
    }
  }

  Future<shelf.Response> handleGetProfileImageRequest(
      shelf.Request request) async {
    // Extract username from the URL
    final username = request.url.pathSegments[1];

    // Retrieve user from the database based on the provided username
    final user = await _databaseManager.getUserByUsername(username);
    if (user != null && user.profileImage != null) {
      // Return the profile image as a response
      return shelf.Response.ok(user.profileImage,
          headers: {'Content-Type': 'image/jpeg'});
    } else {
      // User not found or profile image not available
      return shelf.Response.notFound(
          'Profile image not found for user: $username');
    }
  }

  Future<shelf.Response> handleGroupImageRequest(shelf.Request request) async {
    // Extract group name from the URL

    final groupName = request.url.pathSegments[1];

    // Retrieve group from the database based on the provided group name
    final group = await _databaseManager.getGroupByName(groupName);
    if (group != null && group['groupImage'] != null) {
      // Extract profile image data from the group
      final Uint8List profileImageData = group['groupImage'];

      // Return the profile image as a response
      return shelf.Response.ok(profileImageData,
          headers: {'Content-Type': 'image/jpeg'});
    } else {
      // Group not found or profile image not available
      return shelf.Response.notFound(
          'Profile image not found for group: $groupName');
    }
  }
}
