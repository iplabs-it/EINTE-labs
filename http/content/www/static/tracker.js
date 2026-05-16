// HTTP Lab - Simple tracker script
// This file demonstrates static JavaScript caching

(function() {
    'use strict';
    
    // Log page view
    console.log('[HTTPLab] Page loaded at:', new Date().toISOString());
    console.log('[HTTPLab] This script should be cached with immutable strategy');
    
    // Simple analytics simulation
    const pageData = {
        url: window.location.href,
        timestamp: Date.now(),
        userAgent: navigator.userAgent
    };
    
    console.log('[HTTPLab] Page data:', pageData);
    
    // Add loaded indicator
    document.addEventListener('DOMContentLoaded', function() {
        const footer = document.querySelector('footer');
        if (footer) {
            const indicator = document.createElement('p');
            indicator.textContent = 'Scripts loaded successfully';
            indicator.style.color = '#27ae60';
            indicator.style.fontSize = '0.8em';
            footer.appendChild(indicator);
        }
    });
})();
