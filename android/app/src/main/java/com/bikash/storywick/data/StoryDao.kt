package com.bikash.storywick.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface StoryDao {
    @Query("SELECT * FROM stories ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<Story>>

    @Query("SELECT * FROM stories ORDER BY createdAt DESC")
    suspend fun all(): List<Story>

    @Query("SELECT * FROM stories WHERE id = :id")
    suspend fun get(id: Long): Story?

    @Insert
    suspend fun insert(story: Story): Long

    @Update
    suspend fun update(story: Story)

    @Delete
    suspend fun delete(story: Story)

    @Query("DELETE FROM stories WHERE id = :id")
    suspend fun deleteById(id: Long)
}
