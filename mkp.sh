#!/bin/bash

# Check if project name is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: mkp fullstack-application <name_of_project>"
    exit 1
fi

PROJECT_TYPE=$1
PROJECT_NAME=$2
BASE_DIR="$PWD/$PROJECT_NAME"

# Create project directory
mkdir -p "$BASE_DIR"
cd "$BASE_DIR" || exit

# Backend setup
mkdir backend
cd backend
npm init -y
npm install express mongoose @clerk/clerk-sdk-node dotenv cors

# Create routes directory and auth.js file
mkdir routes
cat <<EOT >> routes/auth.js
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { ClerkExpressRequireAuth } = require('@clerk/clerk-sdk-node');
const requireAuth = ClerkExpressRequireAuth();

router.post('/user', async (req, res) => {
    const { clerkId, username, email } = req.body;

    try {
        let user = await User.findOne({ clerkId });
        if (!user) {
            user = new User({ clerkId, username, email });
            await user.save();
        }

        res.json({
            clerkId: user.clerkId,
            username: user.username,
            email: user.email,
        });
    } catch (error) {
        res.status(500).json({ error: 'Server error', details: error.message });
    }
});

router.get('/profile', requireAuth, async (req, res) => {
    const { userId } = req.auth;

    try {
        const user = await User.findOne({ clerkId: userId });
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json({
            clerkId: user.clerkId,
            username: user.username,
            email: user.email,
        });
    } catch (error) {
        res.status(500).json({ error: 'Server error', details: error.message });
    }
});

module.exports = router;
EOT

# Create models directory and User.js file
cd ..
mkdir models
cat <<EOT >> models/User.js
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  clerkId: {
    type: String,
    required: true,
    unique: true
  },
  username: {
    type: String,
    required: true
  },
  email: {
    type: String,
    required: true
  }
});

const User = mongoose.model('User', userSchema);
module.exports = User;
EOT

# Create basic server structure
cat <<EOT >> server.js
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();
const authRoutes = require('./routes/auth');

const app = express();
app.use(cors());
app.use(express.json());

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error(err));

// Use auth routes
app.use('/api', authRoutes);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(\`Server running on port \${PORT}\`));
EOT

# Prompt for environment variables
read -p "Enter your MongoDB URI: " MONGODB_URI
read -p "Enter your Clerk API Key: " CLERK_API_KEY
read -p "Enter your Clerk API Secret: " CLERK_API_SECRET
read -p "Enter your backend server URL: " BACKEND_URL

# Create .env file
cat <<EOT >> .env
MONGODB_URI=$MONGODB_URI
CLERK_API_KEY=$CLERK_API_KEY
CLERK_API_SECRET=$CLERK_API_SECRET
BACKEND_URL=$BACKEND_URL
EOT

# Frontend setup
cd ..
mkdir frontend
cd frontend
npm init -y
npm install vite react react-dom @clerk/clerk-react
npx vite

# Create basic frontend structure
cat <<EOT >> index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$PROJECT_NAME</title>
</head>
<body>
    <div id="app"></div>
    <script type="module" src="/src/main.jsx"></script>
</body>
</html>
EOT

# Create a basic React entry point
mkdir src
cat <<EOT >> src/main.jsx
import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';

ReactDOM.render(<App />, document.getElementById('app'));
EOT

# Create basic App component
cat <<EOT >> src/App.jsx
import React from 'react';

const App = () => {
    return <h1>Hello, $PROJECT_NAME!</h1>;
};

export default App;
EOT

echo "Setup complete! Navigate to '$BASE_DIR/backend' and '$BASE_DIR/frontend' to start coding."
