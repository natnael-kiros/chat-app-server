import 'dart:convert';

class Person {
  final String name;
  final int age;

  Person(this.name, this.age);

  // toJson method to convert Person object to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
    };
  }
}

void main() {
  // Creating a Person object
  Person person = Person('John Doe', 25);
  print(person);
  // Converting Person to JSON
  Map<String, dynamic> personJson = person.toJson();

  // Printing the JSON representation
  print(personJson);

  // Converting JSON back to a Person object (just for demonstration)
  Person fromJson = Person(personJson['name'], personJson['age']);
  print(fromJson.name); // Output: John Doe
  print(fromJson.age); // Output: 25
}
