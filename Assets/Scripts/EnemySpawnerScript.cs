using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using static Cinemachine.DocumentationSortingAttribute;

public class EnemySpawnerScript : MonoBehaviour
{
    public string levelName;
    public Vector3[] spawnPoints;
    public GameObject[] enemyPrefabs;
    public static List<GameObject> spawnedEnemies = new List<GameObject>();

    // Start is called before the first frame update
    void Awake()
    {
        levelName = SceneManager.GetActiveScene().name;
        //Debug.Log(levelName);

        spawnPoints = new Vector3[3];
        spawnPoints[0] = new Vector3(-31f, 1.6f, 0f);
        spawnPoints[1] = new Vector3(-29f, 1.6f, 0f);
        spawnPoints[2] = new Vector3(-20f, 0.6f, 0f);

        switch (levelName)
        {
            case "Green Greens Level 1":
                SpawnEnemies(spawnPoints);
                break;
            default:
                break;
        }
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void SpawnEnemies(Vector3[] levelSpawnPoints)
    {
        for (int i = 0; i < levelSpawnPoints.Length; i++)
        {
            spawnedEnemies.Add(Instantiate(enemyPrefabs[0], levelSpawnPoints[i], transform.rotation));
        }
    }
}
