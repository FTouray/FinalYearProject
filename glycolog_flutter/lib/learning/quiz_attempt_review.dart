import 'package:flutter/material.dart';

class QuizAttemptReviewPage extends StatelessWidget {
  final List<dynamic> review;
  const QuizAttemptReviewPage({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("📘 Review Past Attempt")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: review.length,
          itemBuilder: (context, index) {
            final q = review[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Q${index + 1}: ${q['question']}",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...List<String>.from(q['options']).map((opt) {
                      final isCorrect = opt == q['correct_answer'];
                      final isChosen = opt == q['user_answer'];
                      final color = isCorrect
                          ? Colors.green.shade100
                          : (isChosen ? Colors.red.shade100 : null);
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isCorrect
                                  ? Colors.green
                                  : (isChosen
                                      ? Colors.red
                                      : Colors.grey.shade300)),
                        ),
                        child: ListTile(
                          title: Text(opt),
                          trailing: isCorrect
                              ? Icon(Icons.check, color: Colors.green)
                              : (isChosen
                                  ? Icon(Icons.close, color: Colors.red)
                                  : null),
                        ),
                      );
                    })
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
