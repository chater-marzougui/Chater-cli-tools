#!/usr/bin/env python3
"""
Chater-Ask Backend - Gemini AI Interface
Simple command-line interface to Google's Gemini AI
"""

import sys
import os
import google.generativeai as genai
from dotenv import load_dotenv
from datetime import datetime
start_time = datetime.now()

model = None

def load_environment(model_name):
    """Load environment variables and configure API"""
    global model
    load_dotenv()
    api_key = os.getenv("GEMINI_API_KEY")
    
    if not api_key:
        print("❌ Error: API key not found.", file=sys.stderr)
        print("Please set the GEMINI_API_KEY environment variable with your Gemini API key.", file=sys.stderr)
        sys.exit(1)
    
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(model_name)
    return model

def ask_gemini(question):
    """Send question to Gemini and get response"""
    global model
    try:        
        # Enhanced prompt for better responses
        enhanced_prompt = f"""
Please provide a helpful, accurate, and concise response to the following question. 
If it's a technical question, include practical examples when appropriate.
If it's a coding question, provide clear code examples with explanations.
This will be used in a CLI environment so adapt your response with: 
 - No large code snippets.
 - Use "-" for bullet points.
 - add spaces before and after bullet points.
 - make the response concise and as direct and short as possible.

return only the main response text.
if question is too ambiguous, ask for clarification or more context.
Also the user is a developer, so serious tone, provide good response with playful tone but absolutely no icons or emojis.
Question: {question}
"""
        
        # Generate response
        response = model.generate_content(enhanced_prompt)
        
        if not response or not response.text:
            print("❌ Error: Empty response from Gemini", file=sys.stderr)
            sys.exit(1)
        
        return response.text
        
    except Exception as e:
        err = str(e)
        if "API key" in err:
            print("❌ Error: Invalid API key", file=sys.stderr)
            print("Please check your GEMINI_API_KEY environment variable.", file=sys.stderr)
        elif "404 models/" in err:
            modelList = []
            for model in genai.list_models():
                modelList.append(model.name[7:]) if "generateContent" in model.supported_generation_methods else None
            print("❌ Error: Model not found. Available models are: ", file=sys.stderr)
            print('\n'.join(modelList), file=sys.stderr)
        else:
            print(f"❌ Error: {str(e)}", file=sys.stderr)
        sys.exit(1)

def main():
    """Main function"""
    # Check if question was provided
    if len(sys.argv) < 2:
        print("❌ Error: No question provided", file=sys.stderr)
        sys.exit(1)
    
    # Join all arguments as the question
    question = sys.argv[1]
    model_name = sys.argv[2] if len(sys.argv) > 2 else 'gemini-2.5-flash-lite'
    timestamp = sys.argv[3] if len(sys.argv) > 3 else None
    enter_time = datetime.fromisoformat(timestamp).replace(tzinfo=None)
    # Validate question
    if not question.strip():
        print("❌ Error: Empty question provided", file=sys.stderr)
        sys.exit(1)
    
    # Get and print response
    try:
        load_environment(model_name)
        print("time to start code:", start_time - enter_time)
        print("time to load model:", datetime.now() - start_time)
        response = ask_gemini(question)
        print("time to get response:", datetime.now() - enter_time)
        print(response, flush=True)
    except KeyboardInterrupt:
        print("\n❌ Operation cancelled by user", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()