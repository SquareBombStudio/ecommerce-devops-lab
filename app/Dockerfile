# Use official Node.js image
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Copy package files and install dependencies
COPY package.json ./
RUN npm install

# Copy app source
COPY server.js ./

# Expose the port the app runs on
EXPOSE 3000

# Start the app
CMD ["node", "server.js"]
