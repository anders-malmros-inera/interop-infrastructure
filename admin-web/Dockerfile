FROM node:18-slim

# Copy the entire repository into the image so the admin-web can access
# other component README files at runtime. We set the workspace root to /workspace
WORKDIR /workspace
COPY . .

# Install dependencies for admin-web
WORKDIR /workspace/admin-web
COPY admin-web/package.json admin-web/package-lock.json* ./
RUN npm install --production

EXPOSE 3000
CMD ["npm", "start"]
