#!/bin/bash
cd /Users/abdullahzulfiqar/Desktop/Abdullah/freelancingwork/interview

echo "=== API Interview System Test Results ==="
echo ""

# Get current interview status
echo "1. Interview Status:"
curl -s http://localhost:3000/api/interviews/1/status | jq '.state | {status, answered_questions, total_questions, progress}'

echo ""
echo "2. Next Question:"
curl -s http://localhost:3000/api/interviews/1/next_question | jq '.question | {question_id, text: .question_text[0:50]}'

echo ""
echo "=== Test Complete ==="
