// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MusicTrust
 * @dev A decentralized music rights management and royalty distribution platform
 */
contract MusicTrust {
    
    struct Song {
        uint256 id;
        string title;
        string artist;
        address owner;
        uint256 royaltyRate; // Percentage in basis points (100 = 1%)
        uint256 totalStreams;
        uint256 totalRoyalties;
        bool isActive;
        uint256 createdAt;
    }
    
    struct RoyaltyPayment {
        uint256 songId;
        address recipient;
        uint256 amount;
        uint256 streams;
        uint256 timestamp;
    }
    
    mapping(uint256 => Song) public songs;
    mapping(address => uint256[]) public artistSongs;
    mapping(uint256 => RoyaltyPayment[]) public songRoyalties;
    
    uint256 public nextSongId = 1;
    uint256 public totalSongs;
    address public owner;
    
    event SongRegistered(
        uint256 indexed songId,
        string title,
        string artist,
        address indexed owner,
        uint256 royaltyRate
    );
    
    event RoyaltyPaid(
        uint256 indexed songId,
        address indexed recipient,
        uint256 amount,
        uint256 streams
    );
    
    event SongUpdated(
        uint256 indexed songId,
        string newTitle,
        uint256 newRoyaltyRate
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }
    
    modifier onlySongOwner(uint256 _songId) {
        require(songs[_songId].owner == msg.sender, "Only song owner can call this function");
        _;
    }
    
    modifier validSong(uint256 _songId) {
        require(songs[_songId].id != 0, "Song does not exist");
        require(songs[_songId].isActive, "Song is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Register a new song with rights management
     * @param _title The title of the song
     * @param _artist The artist name
     * @param _royaltyRate The royalty rate in basis points (100 = 1%)
     */
    function registerSong(
        string memory _title,
        string memory _artist,
        uint256 _royaltyRate
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_artist).length > 0, "Artist cannot be empty");
        require(_royaltyRate <= 10000, "Royalty rate cannot exceed 100%");
        
        uint256 songId = nextSongId++;
        
        songs[songId] = Song({
            id: songId,
            title: _title,
            artist: _artist,
            owner: msg.sender,
            royaltyRate: _royaltyRate,
            totalStreams: 0,
            totalRoyalties: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        artistSongs[msg.sender].push(songId);
        totalSongs++;
        
        emit SongRegistered(songId, _title, _artist, msg.sender, _royaltyRate);
        
        return songId;
    }
    
    /**
     * @dev Distribute royalties to song owner based on streams
     * @param _songId The ID of the song
     * @param _streams Number of streams to pay royalties for
     */
    function distributeRoyalties(uint256 _songId, uint256 _streams) 
        external 
        payable 
        validSong(_songId) 
    {
        require(_streams > 0, "Streams must be greater than 0");
        require(msg.value > 0, "Must send ETH for royalties");
        
        Song storage song = songs[_songId];
        uint256 royaltyAmount = (msg.value * song.royaltyRate) / 10000;
        uint256 platformFee = msg.value - royaltyAmount;
        
        // Update song statistics
        song.totalStreams += _streams;
        song.totalRoyalties += royaltyAmount;
        
        // Record royalty payment
        songRoyalties[_songId].push(RoyaltyPayment({
            songId: _songId,
            recipient: song.owner,
            amount: royaltyAmount,
            streams: _streams,
            timestamp: block.timestamp
        }));
        
        // Transfer royalty to song owner
        payable(song.owner).transfer(royaltyAmount);
        
        // Keep platform fee (remaining balance stays in contract)
        
        emit RoyaltyPaid(_songId, song.owner, royaltyAmount, _streams);
    }
    
    /**
     * @dev Update song information (only by song owner)
     * @param _songId The ID of the song to update
     * @param _newTitle New title for the song
     * @param _newRoyaltyRate New royalty rate in basis points
     */
    function updateSong(
        uint256 _songId,
        string memory _newTitle,
        uint256 _newRoyaltyRate
    ) external onlySongOwner(_songId) validSong(_songId) {
        require(bytes(_newTitle).length > 0, "Title cannot be empty");
        require(_newRoyaltyRate <= 10000, "Royalty rate cannot exceed 100%");
        
        Song storage song = songs[_songId];
        song.title = _newTitle;
        song.royaltyRate = _newRoyaltyRate;
        
        emit SongUpdated(_songId, _newTitle, _newRoyaltyRate);
    }
    
    /**
     * @dev Get song information
     * @param _songId The ID of the song
     */
    function getSong(uint256 _songId) 
        external 
        view 
        returns (
            uint256 id,
            string memory title,
            string memory artist,
            address songOwner,
            uint256 royaltyRate,
            uint256 totalStreams,
            uint256 totalRoyalties,
            bool isActive,
            uint256 createdAt
        ) 
    {
        require(songs[_songId].id != 0, "Song does not exist");
        
        Song memory song = songs[_songId];
        return (
            song.id,
            song.title,
            song.artist,
            song.owner,
            song.royaltyRate,
            song.totalStreams,
            song.totalRoyalties,
            song.isActive,
            song.createdAt
        );
    }
    
    /**
     * @dev Get songs owned by an artist
     * @param _artist The address of the artist
     */
    function getArtistSongs(address _artist) external view returns (uint256[] memory) {
        return artistSongs[_artist];
    }
    
    /**
     * @dev Get royalty payment history for a song
     * @param _songId The ID of the song
     */
    function getRoyaltyHistory(uint256 _songId) 
        external 
        view 
        returns (RoyaltyPayment[] memory) 
    {
        return songRoyalties[_songId];
    }
    
    /**
     * @dev Deactivate a song (only by song owner)
     * @param _songId The ID of the song to deactivate
     */
    function deactivateSong(uint256 _songId) external onlySongOwner(_songId) {
        songs[_songId].isActive = false;
    }
    
    /**
     * @dev Withdraw platform fees (only by contract owner)
     */
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");
        payable(owner).transfer(balance);
    }
    
    /**
     * @dev Get contract statistics
     */
    function getContractStats() 
        external 
        view 
        returns (uint256 totalSongsCount, uint256 contractBalance) 
    {
        return (totalSongs, address(this).balance);
    }
}
