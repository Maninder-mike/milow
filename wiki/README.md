# 📝 GitHub Wiki Upload Instructions

This directory contains all the wiki pages for the Milow GitHub repository.

## Wiki Pages Created

1. **Home.md** - Main wiki homepage with navigation
2. **Installation-Guide.md** - Complete setup instructions
3. **Quick-Start.md** - 5-minute getting started guide
4. **Feature-Overview.md** - Comprehensive feature documentation
5. **Architecture.md** - Technical architecture details
6. **User-Manual.md** - Complete user guide
7. **FAQ.md** - Frequently asked questions
8. **Contributing.md** - Contribution guidelines

## How to Upload to GitHub Wiki

### Method 1: Via GitHub Web Interface

1. Go to your repository: `https://github.com/maninder-mike/milow`
2. Click the "Wiki" tab
3. Click "Create the first page" or "New Page"
4. For each wiki page:
   - Copy the content from the corresponding `.md` file
   - Paste into the wiki editor
   - Use the filename (without `.md`) as the page title
   - Click "Save Page"

### Method 2: Via Git (Recommended)

```bash
# Clone the wiki repository
git clone https://github.com/maninder-mike/milow.wiki.git

# Copy all wiki files
cp wiki/*.md milow.wiki/

# Commit and push
cd milow.wiki
git add .
git commit -m "Add comprehensive wiki documentation"
git push origin master
```

## Wiki Structure

```
Home (Home.md)
├── Getting Started
│   ├── Installation Guide
│   ├── Quick Start
│   └── Configuration
├── Features
│   ├── Feature Overview
│   ├── Trip Management
│   ├── Fuel Tracking
│   └── PDF Export
├── Development
│   ├── Architecture
│   ├── Code Style Guide
│   ├── API Reference
│   └── Contributing
└── User Guides
    ├── User Manual
    ├── FAQ
    └── Troubleshooting
```

## Sidebar Configuration

To create a sidebar, create a file named `_Sidebar.md` with:

```markdown
**Getting Started**
- [Home](Home)
- [Installation Guide](Installation-Guide)
- [Quick Start](Quick-Start)

**Features**
- [Feature Overview](Feature-Overview)
- [Trip Management](Trip-Management)
- [Fuel Tracking](Fuel-Tracking)

**Development**
- [Architecture](Architecture)
- [Contributing](Contributing)

**Help**
- [User Manual](User-Manual)
- [FAQ](FAQ)
```

## Footer Configuration

Create `_Footer.md` with:

```markdown
Made with ❤️ using Flutter | [Report Issue](https://github.com/maninder-mike/milow/issues) | [View Source](https://github.com/maninder-mike/milow)
```

## Maintenance

### Updating Wiki Pages

1. Edit the `.md` files in this directory
2. Push changes to the wiki repository
3. Changes appear immediately on GitHub

### Adding New Pages

1. Create new `.md` file in this directory
2. Add link to Home.md navigation
3. Upload to wiki repository

### Images in Wiki

To add images:

1. Upload images to wiki repository
2. Reference in markdown: `![Alt text](image-name.png)`

## Tips

- Use relative links between wiki pages: `[Link Text](Page-Name)`
- Keep page titles consistent with filenames
- Update Home.md when adding new pages
- Use GitHub-flavored markdown
- Test links after uploading

---

**Ready to upload?** Follow Method 2 (Git) for the easiest process!
