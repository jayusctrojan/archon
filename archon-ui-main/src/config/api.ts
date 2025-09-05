/**
 * Unified API Configuration
 * 
 * This module provides centralized configuration for API endpoints
 * and handles different environments (development, Docker, production)
 */

// Get the API URL from environment or construct it
export function getApiUrl(): string {
  // Always use relative URLs for production deployment
  // This ensures nginx proxy routing works correctly
  if (import.meta.env.PROD || import.meta.env.MODE === 'production') {
    return '';
  }

  // Check if VITE_API_URL is provided (set by docker-compose)
  if (import.meta.env.VITE_API_URL) {
    return import.meta.env.VITE_API_URL;
  }

  // For development, use relative URLs or same port as the UI
  // This ensures development works when UI and API are on the same port
  const protocol = window.location.protocol;
  const host = window.location.hostname;
  const port = window.location.port || '3737';
  
  console.info('[Archon] Development mode - using port:', port);
  
  return `${protocol}//${host}:${port}`;
}

// Get the base path for API endpoints
export function getApiBasePath(): string {
  const apiUrl = getApiUrl();
  
  // If using relative URLs (empty string), just return /api
  if (!apiUrl) {
    return '/api';
  }
  
  // Otherwise, append /api to the base URL
  return `${apiUrl}/api`;
}

// Export commonly used values
export const API_BASE_URL = '/api';  // Always use relative URL for API calls
export const API_FULL_URL = getApiUrl();
