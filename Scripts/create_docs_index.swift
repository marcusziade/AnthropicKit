#!/usr/bin/env swift

import Foundation

let htmlContent = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>AnthropicKit - Swift SDK for Claude API</title>
        <style>
            :root {
                --anthropic-primary: #D4A574;
                --anthropic-secondary: #F5E6D3;
                --anthropic-accent: #8B6F47;
                --anthropic-dark: #2A2522;
                --anthropic-light: #FAF7F4;
                --text-primary: #2A2522;
                --text-secondary: #5A534B;
            }
            
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                background-color: var(--anthropic-light);
                color: var(--text-primary);
                line-height: 1.6;
            }
            
            .hero {
                background: linear-gradient(135deg, var(--anthropic-primary) 0%, var(--anthropic-accent) 100%);
                color: white;
                padding: 80px 20px;
                text-align: center;
                position: relative;
                overflow: hidden;
            }
            
            .hero::before {
                content: '';
                position: absolute;
                top: -50%;
                left: -50%;
                width: 200%;
                height: 200%;
                background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%);
                animation: pulse 4s ease-in-out infinite;
            }
            
            @keyframes pulse {
                0%, 100% { transform: scale(1); opacity: 0.3; }
                50% { transform: scale(1.1); opacity: 0.1; }
            }
            
            .container {
                max-width: 1200px;
                margin: 0 auto;
                padding: 0 20px;
                position: relative;
                z-index: 1;
            }
            
            h1 {
                font-size: 3.5em;
                margin-bottom: 20px;
                font-weight: 700;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.1);
            }
            
            .subtitle {
                font-size: 1.5em;
                margin-bottom: 40px;
                opacity: 0.95;
            }
            
            .buttons {
                display: flex;
                gap: 20px;
                justify-content: center;
                flex-wrap: wrap;
            }
            
            .button {
                display: inline-block;
                padding: 15px 30px;
                background-color: white;
                color: var(--anthropic-primary);
                text-decoration: none;
                border-radius: 8px;
                font-weight: 600;
                transition: all 0.3s ease;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }
            
            .button:hover {
                transform: translateY(-2px);
                box-shadow: 0 6px 12px rgba(0,0,0,0.15);
            }
            
            .button.secondary {
                background-color: transparent;
                color: white;
                border: 2px solid white;
            }
            
            .button.secondary:hover {
                background-color: white;
                color: var(--anthropic-primary);
            }
            
            .features {
                padding: 80px 20px;
                background-color: white;
            }
            
            .features-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 40px;
                margin-top: 60px;
            }
            
            .feature-card {
                background-color: var(--anthropic-secondary);
                padding: 40px;
                border-radius: 12px;
                text-align: center;
                transition: transform 0.3s ease;
            }
            
            .feature-card:hover {
                transform: translateY(-5px);
            }
            
            .feature-icon {
                font-size: 3em;
                margin-bottom: 20px;
            }
            
            .feature-title {
                font-size: 1.5em;
                margin-bottom: 15px;
                color: var(--anthropic-accent);
            }
            
            .platforms {
                padding: 60px 20px;
                text-align: center;
                background-color: var(--anthropic-light);
            }
            
            .platform-icons {
                display: flex;
                justify-content: center;
                gap: 40px;
                margin-top: 40px;
                flex-wrap: wrap;
            }
            
            .platform-icon {
                font-size: 4em;
                color: var(--anthropic-accent);
                transition: transform 0.3s ease;
            }
            
            .platform-icon:hover {
                transform: scale(1.1);
            }
            
            .code-example {
                background-color: var(--anthropic-dark);
                color: #f8f8f2;
                padding: 40px;
                border-radius: 12px;
                margin: 60px auto;
                max-width: 800px;
                overflow-x: auto;
            }
            
            .code-example pre {
                font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
                line-height: 1.5;
            }
            
            .code-keyword { color: #ff79c6; }
            .code-string { color: #f1fa8c; }
            .code-type { color: #8be9fd; }
            .code-property { color: #50fa7b; }
            
            .footer {
                background-color: var(--anthropic-dark);
                color: white;
                padding: 40px 20px;
                text-align: center;
            }
            
            .footer a {
                color: var(--anthropic-primary);
                text-decoration: none;
            }
            
            .footer a:hover {
                text-decoration: underline;
            }
            
            h2 {
                font-size: 2.5em;
                text-align: center;
                margin-bottom: 20px;
                color: var(--anthropic-accent);
            }
        </style>
    </head>
    <body>
        <script>
            // Tutorial URL fallback handler
            document.addEventListener('DOMContentLoaded', function() {
                const tutorialLinks = document.querySelectorAll('a[href*="tutorials"]');
                tutorialLinks.forEach(link => {
                    link.addEventListener('click', function(e) {
                        const href = this.getAttribute('href');
                        // Try multiple possible tutorial paths
                        const possiblePaths = [
                            href,
                            'documentation/anthropickit/tutorials/',
                            'documentation/anthropickit/tutorials/anthropickit/',
                            'documentation/anthropickit/tutorials/anthropickit-tutorials/',
                            'tutorials/anthropickit-tutorials/',
                            'documentation/anthropickit/tutorials/table-of-contents/'
                        ];
                        
                        // Log for debugging
                        console.log('Attempting to navigate to tutorials at:', href);
                    });
                });
            });
        </script>
        <div class="hero">
            <div class="container">
                <h1>AnthropicKit</h1>
                <p class="subtitle">Swift SDK for Claude API - Build intelligent applications with ease</p>
                <div class="buttons">
                    <a href="documentation/anthropickit/" class="button">View Documentation</a>
                    <a href="documentation/anthropickit/tutorials" class="button secondary">Tutorials</a>
                </div>
            </div>
        </div>
        
        <section class="features">
            <div class="container">
                <h2>Why AnthropicKit?</h2>
                <div class="features-grid">
                    <div class="feature-card">
                        <div class="feature-icon">🚀</div>
                        <h3 class="feature-title">Swift-First Design</h3>
                        <p>Built from the ground up for Swift developers with modern async/await support and type safety.</p>
                    </div>
                    <div class="feature-card">
                        <div class="feature-icon">🔧</div>
                        <h3 class="feature-title">Full API Coverage</h3>
                        <p>Complete implementation of Claude's API including messages, streaming, and tool use.</p>
                    </div>
                    <div class="feature-card">
                        <div class="feature-icon">📚</div>
                        <h3 class="feature-title">Interactive Tutorials</h3>
                        <p>Learn by doing with step-by-step tutorials that guide you through building real applications.</p>
                    </div>
                </div>
            </div>
        </section>
        
        <section class="platforms">
            <div class="container">
                <h2>Cross-Platform Support</h2>
                <div class="platform-icons">
                    <span class="platform-icon">🍎</span>
                    <span class="platform-icon">🐧</span>
                    <span class="platform-icon">📱</span>
                    <span class="platform-icon">⌚</span>
                </div>
                <p style="margin-top: 20px; color: var(--text-secondary);">macOS • Linux • iOS • watchOS • tvOS</p>
            </div>
        </section>
        
        <section class="container">
            <div class="code-example">
                <pre><code><span class="code-keyword">import</span> <span class="code-type">AnthropicKit</span>

    <span class="code-keyword">let</span> client = <span class="code-type">AnthropicClient</span>(apiKey: <span class="code-string">"your-api-key"</span>)

    <span class="code-keyword">let</span> message = <span class="code-keyword">try await</span> client.<span class="code-property">messages</span>.<span class="code-property">create</span>(
        model: .<span class="code-property">claude3Opus</span>,
        messages: [
            <span class="code-type">Message</span>(role: .<span class="code-property">user</span>, content: <span class="code-string">"Hello, Claude!"</span>)
        ],
        maxTokens: <span class="code-type">1024</span>
    )

    <span class="code-keyword">print</span>(message.<span class="code-property">content</span>.<span class="code-property">first</span>?.<span class="code-property">text</span> ?? <span class="code-string">""</span>)</code></pre>
            </div>
        </section>
        
        <footer class="footer">
            <div class="container">
                <p style="margin-top: 10px;">
                    <a href="documentation/anthropickit/">Documentation</a> • 
                    <a href="documentation/anthropickit/tutorials">Tutorials</a> • 
                    <a href="https://github.com/marcusziade/AnthropicKit">GitHub</a>
                </p>
            </div>
        </footer>
    </body>
    </html>
    """

let docsPath = "./docs/index.html"
try htmlContent.write(toFile: docsPath, atomically: true, encoding: .utf8)
print("✅ Landing page created at: \\(docsPath)")

