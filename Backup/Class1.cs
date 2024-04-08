using JetBrains.Annotations;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

public class ControllerScript : MonoBehaviour
{
    private Rigidbody2D kirbyBody;

    public Vector2 moveInput;

    const float groundedRadius = .1f;                                          // Distance of the overlap to determine if grounded
    private Vector3 velocity = Vector3.zero;

    private bool facingRight = true;                                            // For determining which way the player is currently facing.

    private float blinkInterval = 5f;
    private float blinkTimer = 0f;

    [SerializeField] private float coyoteTimeCounter;
    [SerializeField] private float coyoteTime = 0.5f;

    private bool allowedToDoubleJump = false;
    private bool hasLetGoJump = false;

    [SerializeField] private Transform groundCheck;
    [SerializeField] private LayerMask whatIsGround;
    [SerializeField] private LayerMask whatIsPlatform;

    [SerializeField] private bool onGround;                                     // Whether or not the player is grounded
    [SerializeField] private bool onPlatform;

    [Range(0, .3f)][SerializeField] private float movementSmoothing = .1f;      // How much to smooth out the movement

    [Header("Events")]
    [Space]

    public UnityEvent OnFallingEvent;
    public UnityEvent OnGroundedEvent;
    public UnityEvent OnBlinkEvent;
    public UnityEvent OnJumpEvent;

    [System.Serializable]
    public class BoolEvent : UnityEvent<bool> { }

    private void Awake()
    {
        kirbyBody = GetComponent<Rigidbody2D>();

        OnFallingEvent ??= new UnityEvent();
        OnGroundedEvent ??= new UnityEvent();
        OnBlinkEvent ??= new UnityEvent();
        OnJumpEvent ??= new UnityEvent();

    }

    private void FixedUpdate()
    {
        onGround = false;

        // The player is grounded if a circlecast to the groundcheck position hits anything designated as ground
        // This can be done using layers instead but Sample Assets will not overwrite your project settings.
        Collider2D[] groundColliders = Physics2D.OverlapCircleAll(groundCheck.position, groundedRadius, whatIsGround);
        for (int i = 0; i < groundColliders.Length; i++)
        {
            if (groundColliders[i].gameObject != gameObject)
            {
                // Grounded
                onGround = true;
                OnGroundedEvent.Invoke();
                allowedToDoubleJump = true;

                // TODO Tripping
            }
        }

        Collider2D[] platformColliders = Physics2D.OverlapCircleAll(groundCheck.position, groundedRadius, whatIsPlatform);
        for (int j = 0; j < platformColliders.Length; j++)
        {
            if (platformColliders[j].gameObject != gameObject)
            {
                // Grounded
                onGround = true;
                OnGroundedEvent.Invoke();
                allowedToDoubleJump = true;

                // TODO Tripping
            }
        }

        if (onGround)
        {
            coyoteTimeCounter = coyoteTime;

            // Blink
            blinkTimer += Time.deltaTime;
            float blinkValue = Mathf.Floor(blinkInterval * UnityEngine.Random.value);
            if (blinkTimer > blinkValue)
            {
                OnBlinkEvent.Invoke();
                blinkTimer = 0;
            }
        }
        else
        {
            coyoteTimeCounter -= Time.deltaTime;
        }


        // Check if Falling
        if (kirbyBody.velocity.y < -0.01f)
        {
            OnFallingEvent.Invoke();
        }
    }

    public void Move(float move, bool jump, float jumpForce, bool crouch)
    {
        // Move the character by finding the target velocity
        Vector3 targetVelocity = new Vector2(move * 10f, kirbyBody.velocity.y);
        // And then smoothing it out and applying it to the character
        kirbyBody.velocity = Vector3.SmoothDamp(kirbyBody.velocity, targetVelocity, ref velocity, movementSmoothing);

        // Flip the player
        if (move > 0 && !facingRight)
            Flip();
        else if (move < 0 && facingRight)
            Flip();

        if (crouch || kirbyBody.velocity.y > 0f)
        {
            IgnorePlatforms(true);
        }
        else if (!crouch && !onGround)
        {
            IgnorePlatforms(false);
        }

        // If the player should jump...
        if (jump && onGround && Mathf.Abs(kirbyBody.velocity.y) < 0.01f)
        {
            Jump(jumpForce, false);
            coyoteTimeCounter = 0f;
        }
        else if (allowedToDoubleJump && jump && hasLetGoJump)
        {
            Jump(jumpForce, true);
            allowedToDoubleJump = false;
        }
        if (!jump)
        {
            hasLetGoJump = true;
        }
        else
        {
            hasLetGoJump = false;
        }
    }

    private void IgnorePlatforms(bool active)
    {
        if (active)
        {
            Physics2D.IgnoreLayerCollision(3, 7, true);
        }
        else
        {
            Physics2D.IgnoreLayerCollision(3, 7, false);
        }
    }

    private void Flip()
    {
        // Rotate 180 on Y-axis
        if (facingRight)
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 180f, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }
        else
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 0, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }


        // Switch the way the player is labelled as facing.
        facingRight = !facingRight;
    }

    private void Jump(float addJumpForce, bool reset)
    {
        // Add a vertical force to the player.
        onGround = false;
        if (reset)
        {
            Vector2 oldVector = kirbyBody.velocity;
            kirbyBody.velocity = new Vector2(oldVector.x, 0f);
        }

        kirbyBody.AddForce(new Vector2(0f, addJumpForce));
        OnJumpEvent.Invoke();
    }
}
