// auth_divider.dart
import 'package:flutter/material.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        SizedBox(
          width: 40,
          child: Divider(color: Color.fromRGBO(0, 0, 0, .2), thickness: .5),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "OR",
            style: TextStyle(
              color: Color.fromRGBO(0, 0, 0, .2),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Divider(color: Color.fromRGBO(0, 0, 0, .2), thickness: .5),
        ),
      ],
    );
  }
}
