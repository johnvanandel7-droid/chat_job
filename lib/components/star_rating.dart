import 'package:flutter/material.dart';

class ReusableStarRating extends StatelessWidget {
  final double rating;
  final double starSize;

  const ReusableStarRating({
    super.key,
    required this.rating,
    required this.starSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating) {
          // Full star or half star
          if (index + 1 <= rating) {
            return Icon(Icons.star, color: Colors.amber, size: starSize);
          } else {
            return Icon(Icons.star_half, color: Colors.amber, size: starSize);
          }
        } else {
          return Icon(Icons.star_border, color: Colors.grey, size: starSize);
        }
      }),
    );
  }
}
